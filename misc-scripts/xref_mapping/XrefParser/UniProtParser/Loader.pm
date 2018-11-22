=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut



package XrefParser::UniProtParser::Loader;

use strict;
use warnings;

use Carp;


sub new {
  my ( $proto, $arg_ref ) = @_;

  my $self = {
              'batch_size'  => $arg_ref->{'batch_size'} // 1,
              'dbh'         => $arg_ref->{'dbh'},
              '_baseParser' => $arg_ref->{'baseParser'},
            };
  my $class = ref $proto || $proto;
  bless $self, $class;
  $self->_clear_send_buffer();

  return $self;
}


sub DESTROY {
  my ( $self ) = @_;

  $self->finish();

  return;
}


sub baseParserInstance {
  my ( $self ) = @_;
  return $self->{'_baseParser'};
}


sub finish {
  my ( $self ) = @_;

  $self->flush();

  return;
}


sub flush {
  my ( $self ) = @_;

  my $bp = $self->baseParserInstance();

  if ( ! $bp->upload_xref_object_graphs($self->{'send_buffer'},
                                        $self->{'dbh'}) ) {
    confess 'Failed to upload xref object graphs. Check for errors on STDOUT';
  }

  $self->_clear_send_buffer();

  return;
}


sub load {
  my ( $self, $transformed_data ) = @_;

  if ( ! defined $transformed_data ) {
    return;
  }

  $self->_add_to_send_buffer( $transformed_data );

  if ( $self->{'send_backlog'} >= $self->{'batch_size'} ) {
    $self->flush();
  }

  return;
}


sub _add_to_send_buffer {
  my ( $self, $entry ) = @_;

  push @{ $self->{'send_buffer'} }, $entry;
  $self->{'send_backlog'}++;

  return;
}


sub _clear_send_buffer {
  my ( $self ) = @_;

  $self->{'send_buffer'}  = [];
  $self->{'send_backlog'} = 0;

  return;
}


1;
