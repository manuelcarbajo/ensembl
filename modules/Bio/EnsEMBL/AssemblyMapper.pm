
#
# Ensembl module for Bio::EnsEMBL::AssemblyMapper
#
# Written by Arne Stabenau <stabenau@ebi.ac.uk>
#
# Copyright GRL and EBI
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::AssemblyMapper - 
Handles mapping between two coordinate systems using the information stored in
the assembly table

=head1 SYNOPSIS
    $db = Bio::EnsEMBL::DBSQL::DBAdaptor->new(...);
    $asma = $db->get_AssemblyMapperAdaptor();
    $csa  = $db->get_CoordSystemAdaptor();

    my $chr_cs = $cs_adaptor->fetch_by_name('chromosome', 'NCBI33');
    my $ctg_cs   = $cs_adaptor->fetch_by_name('contig');

    $asm_mapper = $map_adaptor->fetch_by_CoordSystems($cs1, $cs2);

    #map to contig coordinate system from chromosomal
    @ctg_coords = $asm_mapper->map('X', 1_000_000, 2_000_000, 1, $chr_cs);

    #map to chromosome coordinate system from contig
    @chr_coords = $asm_mapper->map('AL30421.1.200.92341',100,10000,-1,$ctg_cs);

    #list contig names for a region of chromsome
    @ctg_ids = $asm_mapper->list_ids('13', 1_000_000, 1, $chr_cs);

    #list chromosome names for a contig region
    @chr_ids = $asm_mapper->list_ids('AL30421.1.200.92341',1,1000,-1,$ctg_cs);

=head1 DESCRIPTION

The AssemblyMapper is a database aware mapper which faciliates conversion
of coordinates between any two coordinate systems with an relationship
explicitly defined in the assembly table.  In the future it may be possible to
perform multiple step (implicit) mapping between coordinate systems.

It is implemented using the Bio::EnsEMBL::Mapper object, which is a generic
mapper object between disjoint coordinate systems.

=head1 CONTACT

Post general queries to B<ensembl-dev@ebi.ac.uk>

=head1 METHODS

=cut


package Bio::EnsEMBL::AssemblyMapper;

use strict;
use warnings;

use Bio::EnsEMBL::Mapper;
use Bio::EnsEMBL::Utils::Exception qw(throw deprecate);

my $ASSEMBLED = 'assembled';
my $COMPONENT = 'component';

my $DEFAULT_MAX_PAIR_COUNT = 1000;



=head2 new

  Arg [1]    : Bio::EnsEMBL::DBSQL::AssemblyMapperAdaptor
  Arg [2]    : Bio::EnsEMBL::CoordSystem $asm_cs
  Arg [3]    : Bio::EnsEMBL::CoordSystem $cmp_cs
  Example    : Should use AssemblyMapperAdaptor->fetch_by_CoordSystems
  Description: Creates a new AssemblyMapper
  Returntype : Bio::EnsEMBL::DBSQL::AssemblyMapperAdaptor
  Exceptions : thrown if multiple coord_systems are provided
  Caller     : AssemblyMapperAdaptor

=cut

sub new {
  my ($caller,$adaptor,@coord_systems) = @_;

  my $class = ref($caller) || $caller;

  my $self = {};
  bless $self, $class;

  $self->adaptor($adaptor);

  if(@coord_systems != 2) {
    throw('Can only map between 2 coordinate systems. ' .
          scalar(@coord_systems) . ' were provided');
  }

  # Set the component and assembled coordinate systems
  $self->{'asm_cs'} = $coord_systems[0];
  $self->{'cmp_cs'} = $coord_systems[1];

  #we load the mapper calling the 'ASSEMBLED' the 'from' coord system
  #and the 'COMPONENT' the 'to' coord system
  $self->{'mapper'} = Bio::EnsEMBL::Mapper->new($ASSEMBLED, $COMPONENT,
                                               $coord_systems[0],
                                               $coord_systems[1]);


  $self->{'max_pair_count'} = $DEFAULT_MAX_PAIR_COUNT;

  return $self;
}





=head2 max_pair_count

  Arg [1]    : (optional) int $max_pair_count
  Example    : $mapper->max_pair_count(100000)
  Description: Getter/Setter for the number of mapping pairs allowed in the
               internal cache. This can be used to override the default value
               (1000) to tune the performance and memory usage for certain
               scenarios. Higher value = bigger cache, more memory used
  Returntype : int
  Exceptions : none
  Caller     : general

=cut

sub max_pair_count {
  my $self = shift;
  $self->{'max_pair_count'} = shift if(@_);
  return $self->{'max_pair_count'};
}



=head2 map

  Arg [1]    : string $frm_seq_region
               The name of the sequence region to transform FROM
  Arg [2]    : int $frm_start
               The start of the region to transform FROM
  Arg [3]    : int $frm_end
               The end of the region to transform FROM
  Arg [4]    : int $strand
               The strand of the region to transform FROM
  Arg [5]    : Bio::EnsEMBL::CoordSystem
               The coordinate system to transform FROM
  Example    : @coords = $asm_mapper->map('X', 1_000_000, 2_000_000,
                                            1, $chr_cs);
  Description: Transforms coordinates from one coordinate system
               to another.
  Returntype : List of Bio::EnsEMBL::Mapper::Coordinate and/or
               Bio::EnsEMBL::Mapper:Gap objects
  Exceptions : thrown if if the specified TO coordinat system is not one
               of the coordinate systems associated with this assembly mapper
  Caller     : general

=cut

sub map {
  throw('Incorrect number of arguments.') if(@_ != 6);

  my ($self, $frm_seq_region, $frm_start, $frm_end, $frm_strand, $frm_cs) = @_;

  my $mapper  = $self->{'mapper'};
  my $asm_cs  = $self->{'asm_cs'};
  my $cmp_cs  = $self->{'cmp_cs'};
  my $adaptor = $self->{'adaptor'};
  my $frm;

  #speed critical section:
  #try to do simple pointer equality comparisons of the coord system objects
  #first since this is likely to work most of the time and is much faster
  #than a function call

  if($frm_cs == $cmp_cs || ($frm_cs != $asm_cs && $frm_cs->equals($cmp_cs))) {

    if(!$self->{'cmp_register'}->{$frm_seq_region}) {
      $adaptor->register_component($self,$frm_seq_region);
    }
    $frm = $COMPONENT;

  } elsif($frm_cs == $asm_cs || $frm_cs->equals($asm_cs)) {

    # This can be probably be sped up some by only calling registered
    # assembled if needed
    $adaptor->register_assembled($self,$frm_seq_region,$frm_start,$frm_end);
    $frm = $ASSEMBLED;

  } else {

    throw("Coordinate system " . $frm_cs->name . " " . $frm_cs->version .
          " is neither the assembled nor the component coordinate system " .
          " of this AssemblyMapper");
  }

  return $mapper->map_coordinates($frm_seq_region, $frm_start, $frm_end,
                                  $frm_strand, $frm);
}



=head2 flush

  Args       : none
  Example    : none
  Description: remove all cached items from this AssemblyMapper
  Returntype : none
  Exceptions : none
  Caller     : AssemblyMapperAdaptor

=cut

sub flush {
  my $self = shift;

  $self->{'mapper'}->flush();
  $self->{'cmp_register'} = {};
  $self->{'asm_register'} = {};
}


sub size {
  my $self = shift;
  return $self->{'mapper'}->{'pair_count'};
}



sub fastmap {
  throw('Incorrect number of arguments.') if(@_ != 6);

  my ($self, $frm_seq_region, $frm_start, $frm_end, $frm_strand, $frm_cs) = @_;

  my $mapper  = $self->{'mapper'};
  my $asm_cs  = $self->{'asm_cs'};
  my $cmp_cs  = $self->{'cmp_cs'};
  my $adaptor = $self->{'adaptor'};
  my $frm;

  #speed critical section:
  #try to do simple pointer equality comparisons of the coord system objects
  #first since this is likely to work most of the time and is much faster
  #than a function call

  if($frm_cs == $cmp_cs || ($frm_cs != $asm_cs && $frm_cs->equals($cmp_cs))) {

    if(!$self->{'cmp_register'}->{$frm_seq_region}) {
      $adaptor->register_component($self,$frm_seq_region);
    }
    $frm = $COMPONENT;

  } elsif($frm_cs == $asm_cs || $frm_cs->equals($asm_cs)) {

    # This can be probably be sped up some by only calling registered
    # assembled if needed
    $adaptor->register_assembled($self,$frm_seq_region,$frm_start,$frm_end);
    $frm = $ASSEMBLED;

  } else {

    throw("Coordinate system " . $frm_cs->name . " " . $frm_cs->version .
          " is neither the assembled nor the component coordinate system " .
          " of this AssemblyMapper");
  }

  return $mapper->fastmap($frm_seq_region, $frm_start, $frm_end,
                          $frm_strand, $frm);
}



=head2 list_seq_regions

  Arg [1]    : string $frm_seq_region
               The name of the sequence region of interest
  Arg [2]    : int $frm_start
               The start of the region of interest
  Arg [3]    : int $frm_end
               The end of the region to transform of interest
  Arg [5]    : Bio::EnsEMBL::CoordSystem $frm_cs
               The coordinate system to obtain overlapping ids of
  Example    : foreach $id ($asm_mapper->list_ids('X',1,1000,$ctg_cs)) {...}
  Description: Retrieves a list of overlapping seq_region names
               of another coordinate system.  This is the same as the 
               list_ids method but uses seq_region names rather internal ids
  Returntype : List of strings
  Exceptions : none
  Caller     : general

=cut


sub list_seq_regions {
  throw('Incorrect number of arguments.') if(@_ != 5);
  my($self, $frm_seq_region, $frm_start, $frm_end, $frm_cs) = @_;

  if($frm_cs->equals($self->component_CoordSystem())) {

    if(!$self->have_registered_component($frm_seq_region)) {
      $self->adaptor->register_component($frm_seq_region);
    }

    #pull out the 'from' identifiers of the mapper pairs.  The
    #we loaded the assembled side as the 'from' side in the constructor
    return
      map {$_->from()->id()}
      $self->mapper()->list_pairs($frm_seq_region, $frm_start,
                                  $frm_end, $COMPONENT);

  } elsif($frm_cs->equals($self->assembled_CoordSystem())) {

    $self->adaptor->register_assembled($self,
                                       $frm_seq_region,$frm_start,$frm_end);

    #pull out the 'to' identifiers of the mapper pairs
    #we loaded the component side as the 'to' coord system in the constructor
    return
      map {$_->to->id()}
        $self->mapper()->list_pairs($frm_seq_region, $frm_start,
                                    $frm_end, $ASSEMBLED);
  } else {
    throw("Coordinate system " . $frm_cs->name . " " . $frm_cs->version .
          " is neither the assembled nor the component coordinate system " .
          " of this AssemblyMapper");
  }
}


=head2 list_ids

  Arg [1]    : string $frm_seq_region
               The name of the sequence region of interest
  Arg [2]    : int $frm_start
               The start of the region of interest
  Arg [3]    : int $frm_end
               The end of the region to transform of interest
  Arg [5]    : Bio::EnsEMBL::CoordSystem $frm_cs
               The coordinate system to obtain overlapping ids of
  Example    : foreach $id ($asm_mapper->list_ids('X',1,1000,$chr_cs)) {...}
  Description: Retrieves a list of overlapping seq_region internal identifiers
               of another coordinate system.  This is the same as the
               list_seq_regions method but uses internal identfiers rather 
               than seq_region strings
  Returntype : List of ints
  Exceptions : none
  Caller     : general

=cut

sub list_ids {
  throw('Incorrect number of arguments.') if(@_ != 5);
  my($self, $frm_seq_region, $frm_start, $frm_end, $frm_cs) = @_;

  #retrieve the seq_region names
  my @seq_regs =
    $self->list_seq_regions($frm_seq_region,$frm_start,$frm_end,$frm_cs);

  #The seq_regions are from the 'to' coordinate system not the
  #from coordinate system we used to obtain them
  my $to_cs;
  if($frm_cs->equals($self->assembled_CoordSystem())) {
    $to_cs = $self->component_CoordSystem();
  } else {
    $to_cs = $self->assembled_CoordSystem();
  }

  #convert them to ids
  return @{$self->adaptor()->seq_regions_to_ids($to_cs, \@seq_regs)};
}




=head2 have_registered_component

  Arg [1]    : string $cmp_seq_region
               The name of the sequence region to check for registration
  Example    : if($asm_mapper->have_registered_component('AL240214.1')) {...}
  Description: Returns true if a given component region has been registered
               with this assembly mapper.  This should only be called
               by this class or the AssemblyMapperAdaptor.  Anotherwards, do
               not use this method unless you really know what you are doing.
  Returntype : 0 or 1
  Exceptions : throw on incorrect arguments
  Caller     : internal, AssemblyMapperAdaptor

=cut

sub have_registered_component {
  my $self = shift;
  my $cmp_seq_region = shift;

  throw('cmp_seq_region argument is required') if(!$cmp_seq_region);

  if($self->{'cmp_register'}->{$cmp_seq_region}) {
    return 1;
  }

  return 0;
}



=head2 have_registered_assembled

  Arg [1]    : string $asm_seq_region
               The name of the sequence region to check for registration
  Arg [2]    : int $chunk_id
               The chunk number of the provided seq_region to check for
               registration.
  Example    : if($asm_mapper->have_registered_component('X',9)) {...}
  Description: Returns true if a given assembled region chunk has been
               registered with this assembly mapper.  This should only
               be called by this class or the AssemblyMapperAdaptor.
               Anotherwards do not use this method unless you really know what
               you are doing.
  Returntype : 0 or 1
  Exceptions : throw on incorrect arguments
  Caller     : internal, AssemblyMapperAdaptor

=cut

sub have_registered_assembled {
  my $self = shift;
  my $asm_seq_region = shift;
  my $chunk_id   = shift;

  throw('asm_seq_region argument is required') if(!$asm_seq_region);
  throw('chunk_id is required') if(!defined($chunk_id));

  if($self->{'asm_register'}->{$asm_seq_region}->{$chunk_id}) {
    return 1;
  }

  return 0;
}


=head2 register_component

  Arg [1]    : string $cmp_seq_region
               The name of the component sequence region to register
  Example    : $asm_mapper->register_component('AL312341.1');
  Description: Flags a given component sequence region as registered in this
               assembly mapper.  This should only be called by this class
               or the AssemblyMapperAdaptor.
  Returntype : none
  Exceptions : throw on incorrect arguments
  Caller     : internal, AssemblyMapperAdaptor

=cut

sub register_component {
  my $self = shift;
  my $cmp_seq_region = shift;

  throw('cmp_seq_region argument is required') if(!$cmp_seq_region);

  $self->{'cmp_register'}->{$cmp_seq_region} = 1;
}


=head2 register_assembled

  Arg [1]    : string $asm_seq_region
               The name of the sequence region to register
  Arg [2]    : int $chunk_id
               The chunk number of the provided seq_region to register.
  Example    : $asm_mapper->register_assembled('X', 4);
  Description: Flags a given assembled region as registered in this assembly
               mapper.  This should only be called by this class or the
               AssemblyMapperAdaptor. Do not call this method unless you
               really know what you are doing.
  Returntype : none
  Exceptions : throw on incorrect arguments
  Caller     : internal, AssemblyMapperAdaptor

=cut

sub register_assembled {
  my $self = shift;
  my $asm_seq_region = shift;
  my $chunk_id = shift;

  throw('asm_seq_region argument is required') if(!$asm_seq_region);
  throw('chunk_id srgument is required') if(!defined($chunk_id));

  $self->{'asm_register'}->{$asm_seq_region}->{$chunk_id} = 1;
}



=head2 mapper

  Arg [1]    : none
  Example    : $mapper = $asm_mapper->mapper();
  Description: Retrieves the internal mapper used by this Assembly Mapper.
               This is unlikely to be useful unless you _really_ know what you
               are doing.
  Returntype : Bio::EnsEMBL::Mapper
  Exceptions : none
  Caller     : internal, AssemblyMapperAdaptor

=cut

sub mapper {
  my $self = shift;
  return $self->{'mapper'};
}


=head2 assembled_CoordSystem

  Arg [1]    : none
  Example    : $cs = $asm_mapper->assembled_CoordSystem
  Description: Retrieves the assembled CoordSystem from this assembly mapper
  Returntype : Bio::EnsEMBL::CoordSystem
  Exceptions : none
  Caller     : internal, AssemblyMapperAdaptor

=cut

sub assembled_CoordSystem {
  my $self = shift;
  return $self->{'asm_cs'};
}


=head2 component_CoordSystem

  Arg [1]    : none
  Example    : $cs = $asm_mapper->component_CoordSystem
  Description: Retrieves the component CoordSystem from this assembly mapper
  Returntype : Bio::EnsEMBL::CoordSystem
  Exceptions : none
  Caller     : internal, AssemblyMapperAdaptor

=cut

sub component_CoordSystem {
  my $self = shift;
  return $self->{'cmp_cs'};
}


=head2 adaptor

  Arg [1]    : Bio::EnsEMBL::DBSQL::AssemblyMapperAdaptor $adaptor
  Example    : none
  Description: get/set for this objects database adaptor
  Returntype : Bio::EnsEMBL::DBSQL::AssemblyMapperAdaptor
  Exceptions : none
  Caller     : general

=cut


sub adaptor {
  my $self = shift;
  $self->{'adaptor'} = shift if(@_);
  return $self->{'adaptor'};
}


=head2 in_assembly

  Description: Deprecated. Use map() or list_ids() instead

=cut

sub in_assembly {
  my ($self, $object) = @_;

  deprecate('Use map() or list_ids() instead.');

  my $csa = $self->db->get_CoordSystemAdaptor();

  my $top_level = $csa->fetch_top_level();

  my $asma = $self->adaptor->fetch_by_CoordSystems($object->coord_system(),
                                                   $top_level);

  my @list = $asma->list_ids($object->seq_region(), $object->start(),
                             $object->end(), $object->coord_system());

  return (@list > 0);
}


=head2 map_coordinates_to_assembly

  Description: DEPRECATED use map() instead

=cut

sub map_coordinates_to_assembly {
  my ($self, $contig_id, $start, $end, $strand) = @_;

  deprecate('Use map() instead.');

  #not sure if contig_id is seq_region_id or name...
  return $self->map($contig_id, $start, $end, $strand,
                   $self->contig_CoordSystem());

}


=head2 fast_to_assembly

  Description: DEPRECATED use map() instead

=cut

sub fast_to_assembly {
  my ($self, $contig_id, $start, $end, $strand) = @_;

  deprecate('Use map() instead.');

  #not sure if contig_id is seq_region_id or name...
  return $self->map($contig_id, $start, $end, $strand,
                    $self->contig_CoordSystem());
}


=head2 map_coordinates_to_rawcontig

  Description: DEPRECATED use map() instead

=cut

sub map_coordinates_to_rawcontig {
  my ($self, $chr_name, $start, $end, $strand) = @_;

  deprecate('Use map() instead.');

  return $self->map($chr_name, $start, $end, $strand,
                    $self->assembled_CoordSystem());

}

=head2 list_contig_ids
  Description: DEPRECATED Use list_ids instead

=cut

sub list_contig_ids {
  my ($self, $chr_name, $start, $end) = @_;

  deprecate('Use list_ids() instead.');

  return $self->list_ids($chr_name, $start, $end, 
                         $self->assembled_CoordSystem());
}



1;
