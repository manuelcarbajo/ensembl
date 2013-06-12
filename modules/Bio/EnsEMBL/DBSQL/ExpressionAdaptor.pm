=head1 LICENSE

  Copyright (c) 1999-2012 The European Bioinformatics Institute and
  Genome Research Limited.  All rights reserved.

  This software is distributed under a modified Apache license.
  For license details, please see

    http://www.ensembl.org/info/about/code_licence.html

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=cut

=head1 NAME

Bio::EnsEMBL::DBSQL::ExpressionAdaptor - Provides database interaction for
Bio::EnsEMBL::Expression objects.


=head1 SYNOPSIS

  # $db is a Bio::EnsEMBL::DBSQL::DBAdaptor object:
  $expression_adaptor = $db->get_ExpressionAdaptor();

  $attributes = $expression_adaptor->fetch_all_by_gene($tissue);

  $expression_adaptor->store_on_Gene( $gene, \@expressions);


=head1 DESCRIPTION

=head1 METHODS

=cut

package Bio::EnsEMBL::DBSQL::ExpressionAdaptor;

use strict;
use warnings;


use Bio::EnsEMBL::DBSQL::BaseAdaptor;
use Bio::EnsEMBL::Expression;

use Bio::EnsEMBL::Utils::Exception qw(throw warning);
use Bio::EnsEMBL::Utils::Scalar qw(assert_ref);

use vars qw(@ISA);

@ISA = qw(Bio::EnsEMBL::DBSQL::BaseAdaptor);


=head2 new

  Arg [...]  : Superclass args.  See Bio::EnsEMBL::DBSQL::BaseAdaptor
  Description: Instantiates a Bio::EnsEMBL::DBSQL::AttributeAdaptor
  Returntype : Bio::EnsEMBL::AttributeAdaptor
  Exceptions : none
  Caller     : DBAdaptor
  Status     : Stable

=cut


sub new {
  my $class = shift;

  my $self = $class->SUPER::new(@_);


  # cache creation could go here
  return $self;
}



sub store_on_Object {
  my ($self, $object, $expressions, $table) = @_;

  my $object_id = $object->dbID();

  my $sth = $self->prepare( "INSERT into ".$table."_expression ".
			    "SET ".$table."_id = ?, tissue_id = ?, ".
			    "value = ?, analysis_id = ?, value_type = ?" );

  for my $exp ( @$expressions) {

    if(!ref($exp) && $exp->isa('Bio::EnsEMBL::Expression')) {
      throw("Reference to list of Bio::EnsEMBL::Expression objects " .
            "argument expected.");
    }

    my $expid = $self->_store_type( $exp);
    
    my $an_id;
    my $analysis = $exp->analysis();
    if ($analysis->is_stored($self->db)){
      $an_id = $analysis->dbID();
    } else {
      $an_id = $self->db->get_AnalysisAdaptor->store($analysis);
    }
    $sth->bind_param(1,$object_id,SQL_INTEGER);
    $sth->bind_param(2,$expid,SQL_INTEGER);
    $sth->bind_param(3,$exp->value,SQL_VARCHAR);
    $sth->bind_param(4,$an_id, SQL_INTEGER);
    $sth->bind_param(5,$exp->value_type,SQL_VARCHAR);
    $sth->execute();
  }

  return;
}

sub store_on_Gene {
  my ($self, $object, $expressions) = @_;

  $self->store_on_Object($object, $expressions, 'gene');

  return;
}

sub store_on_Transcript {
  my ($self, $object, $expressions) = @_;

  $self->store_on_Object($object, $expressions, 'transcript');

  return;
}

sub store_on_Exon {
  my ($self, $object, $expressions) = @_;

  $self->store_on_Object($object, $expressions, 'exon');

  return;
}


sub remove_from_Object {
  my ($self, $object, $table, $name, $logic_name) = @_;

  my $object_id = $object->dbID();

  if(!defined($object_id)) {
    throw("$table must have dbID.");
  }

  my $sql = "DELETE e FROM ".$table."_expression e, tissue t " .
                         "WHERE ".$table."_id = " . $object_id .
                         " AND t.tissue_id = e.tissue_id";
  if(defined($name)){
    $sql .= " AND t.name like '" . $name . "'"; 
  }
  if (defined($logic_name)){
    my $aa = $self->db->get_AnalysisAdaptor();
    my $an = $aa->fetch_by_logic_name($logic_name);
    my $an_id = $an->dbID();
    $sql .= " AND e.analysis_id = " . $an_id;
  }
  my $sth = $self->prepare($sql);
  $sth->execute();

  $sth->finish();

  return;
}

sub remove_from_Gene {
  my ($self, $object, $name, $logic_name) = @_;

  assert_ref($object, 'Bio::EnsEMBL::Gene');

  $self->remove_from_Object($object, 'gene', $name, $logic_name);

  return;
}

sub remove_from_Transcript {
  my ($self, $object, $name, $logic_name) = @_;

  assert_ref($object, 'Bio::EnsEMBL::Transcript');

  $self->remove_from_Object($object, 'transcript', $name, $logic_name);

  return;
}

sub remove_from_Exon {
  my ($self, $object, $name, $logic_name) = @_;

  assert_ref($object, 'Bio::EnsEMBL::Exon');

  $self->remove_from_Object($object, 'exon', $name, $logic_name);

  return;
}


sub get_all_tissues {
  my $self  = shift;

  my $sql = "SELECT DISTINCT name FROM tissue";
  my $sth = $self->prepare($sql);
  $sth->execute();
  my ($name, @out);

  $sth->bind_columns(\$name);
  while ($sth->fetch()) {
    push @out, $name;
  }
  return \@out;
}



sub fetch_all_by_Object {
  my ($self, $object, $table, $name, $logic_name, $value_type, $cutoff) = @_;

  my $object_id;
  $object_id = $object->dbID() if defined $object;
  my $aa = $self->db->get_AnalysisAdaptor();
  my @out;

  my $sql = "SELECT t.name, t.description, t.ontology, e.".$table."_id, e.value, e.analysis_id, e.value_type " .
              "FROM ".$table."_expression e, tissue t ".
                 "WHERE e.tissue_id = t.tissue_id";

  if(defined($name)){
    $sql .= " AND t.name like '" . $name . "'";
  }
  if(defined($object_id)){
    $sql .= " AND e.".$table."_id = ".$object_id;
  }
  if (defined($logic_name)){
    my $an = $aa->fetch_by_logic_name($logic_name);
    if (!defined $an) {
      @out = undef;
      return [];
    }
    my $an_id = $an->dbID();
    $sql .= " AND e.analysis_id = " . $an_id;
  }
  if (defined($value_type)){
    $sql .= " AND e.value_type = '" . $value_type . "'";
  }
  if (defined($cutoff)){
    $sql .= " AND e.value > $cutoff";
  }
		   
  my $sth = $self->prepare($sql);
  $sth->execute();
  my ($desc, $ontology, $value, $analysis_id);
  $sth->bind_columns(\$name, \$desc, \$ontology, \$object_id, \$value, \$analysis_id, \$value_type);

  my $object_adaptor = "get_" . $table . "Adaptor";
  my $adaptor = $self->db->$object_adaptor();

  while ($sth->fetch()) {

    my $analysis = $aa->fetch_by_dbID($analysis_id);
    my $object = $adaptor->fetch_by_dbID($object_id);

    my $exp = Bio::EnsEMBL::Expression->new_fast
              ( {'name'        => $name,
                 'description' => $desc,
                 'ontology'    => $ontology,
                 'analysis'    => $analysis,
                 'value_type'  => $value_type,
                 'object'      => $object,
                 'value'       => $value} );
    push @out, $exp;
  }

  $sth->finish();

  return \@out;
  
}

sub fetch_all_by_Gene {
  my ($self, $object, $name, $logic_name, $value_type, $cutoff) = @_;

  if (defined($object)){
    assert_ref($object, 'Bio::EnsEMBL::Gene');
  }

  my $out = $self->fetch_all_by_Object($object, 'gene', $name, $logic_name, $value_type, $cutoff);

  return $out;
}

sub fetch_all_by_Transcript {
  my ($self, $object, $name, $logic_name, $value_type, $cutoff) = @_;

  if (defined($object)){
    assert_ref($object, 'Bio::EnsEMBL::Transcript');
  }

  my $out = $self->fetch_all_by_Object($object, 'transcript', $name, $logic_name, $value_type, $cutoff);

  return $out;
}

sub fetch_all_by_Exon {
  my ($self, $object, $name, $logic_name, $value_type, $cutoff) = @_;

  if (defined($object)){
    assert_ref($object, 'Bio::EnsEMBL::Exon');
  }

  my $out = $self->fetch_all_by_Object($object, 'exon', $name, $logic_name, $value_type, $cutoff);

  return $out;
}



# _store_type

sub _store_type {
  my $self   = shift;
  my $tissue = shift;

  my $sth1 = $self->prepare
    ("INSERT IGNORE INTO tissue set name = ?, description = ?, ontology = ?" );

  $sth1->bind_param(1,$tissue->name,SQL_VARCHAR);
  $sth1->bind_param(2,$tissue->description,SQL_LONGVARCHAR);
  $sth1->bind_param(3,$tissue->ontology,SQL_VARCHAR);

  my $rows_inserted =  $sth1->execute();

  my $atid = $sth1->{'mysql_insertid'};

  if($rows_inserted == 0) {
    # the insert failed because the tissue is already stored
    my $sth2 = $self->prepare
      ("SELECT tissue_id FROM tissue " .
       "WHERE name = ?");
    $sth2->bind_param(1,$tissue->name,SQL_VARCHAR);
    $sth2->execute();
    ($atid) = $sth2->fetchrow_array();

    $sth2->finish();

    if(!$atid) {
      throw("Could not store or fetch tissue [".$tissue->name."]\n" .
	    "Wrong database user/permissions?");
    }
  }


  $sth1->finish();

  return $atid;
}



1;

