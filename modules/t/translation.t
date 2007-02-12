use strict;
use warnings;

use Bio::EnsEMBL::Test::TestUtils;
use Bio::EnsEMBL::Translation;
use Bio::EnsEMBL::Exon;

BEGIN { $| = 1;
	use Test;
	plan tests => 36;
}

my $loaded = 0;
END {print "not ok 1\n" unless $loaded;}

#turn on/off debug prints:
our $verbose = 0;

use Bio::EnsEMBL::Test::MultiTestDB;

my $multi = Bio::EnsEMBL::Test::MultiTestDB->new();

$loaded = 1;

ok(1);

my $db = $multi->get_DBAdaptor( 'core' );

my $t = Bio::EnsEMBL::Translation->new();

ok($t);

ok( test_getter_setter( $t, "stable_id", 1 ));
ok( test_getter_setter( $t, "created_date", time() ));
ok( test_getter_setter( $t, "modified_date", time() ));

ok(test_getter_setter($t,'dbID',3));

ok(test_getter_setter($t,'start',42));
ok(test_getter_setter($t,'end',50));

my $exon = Bio::EnsEMBL::Exon->new();
$exon->start(10);
$exon->end(20);
$exon->strand(1);
$exon->phase(0);
$exon->end_phase( -1 );

$t->start_Exon($exon);
ok($t);

$t->end_Exon($exon);
ok($t);


#
# Tests for the translation adaptor
##################################

my $ta = $db->get_TranslationAdaptor();
my $ids = $ta->list_dbIDs();
ok (@{$ids});

my $stable_ids = $ta->list_stable_ids();
ok (@{$stable_ids});


my $tra = $db->get_TranscriptAdaptor();

my $transcript = $tra->fetch_by_stable_id('ENST00000201961');

#
# test fetch_by_Transcript
#
my $translation = $ta->fetch_by_Transcript($transcript);

ok($translation && $translation->stable_id eq 'ENSP00000201961');

my @date_time = localtime( $translation->created_date());
ok( $date_time[3] == 6 && $date_time[4] == 11 && $date_time[5] == 104 );

@date_time = localtime( $translation->modified_date());
ok( $date_time[3] == 6 && $date_time[4] == 11 && $date_time[5] == 104 );

ok($translation && $translation->start_Exon->stable_id eq 'ENSE00000661216');
ok($translation && $translation->end_Exon->stable_id eq 'ENSE00000661212');


#
# test fetch_by_dbID
#
$translation = $ta->fetch_by_dbID(21734);
ok($translation && $translation->stable_id() eq 'ENSP00000201961');


#
# test fetch_by_stable_id
#
$translation = $ta->fetch_by_stable_id('ENSP00000201961');
ok($translation && $translation->dbID() == 21734);

#
# test fetch_by_external_name
#
($translation) = @{$ta->fetch_all_by_external_name('CAC33959')};
ok($translation && $translation->dbID() == 21716);

#
# test get_all_ProteinFeatures
#

my @protein_features = @{$translation->get_all_ProteinFeatures()};
debug("Got " . scalar(@protein_features) ." protein features.");
ok(@protein_features == 3);


#
# test get_all_DomainFeatures
#
my @domain_features = @{$translation->get_all_DomainFeatures()};
debug("Got " . scalar(@domain_features) . " domain features.");
ok(@domain_features == 3);

ok($translation->display_id eq $translation->stable_id);

#
# test that when manually attaching ProteinFeatures they are not loaded from
# the db
#
$translation->{'protein_features'} = undef;

my $pfa = $translation->adaptor->db->get_ProteinFeatureAdaptor;
my $protein_feature = $pfa->fetch_by_dbID(27374);
$translation->add_ProteinFeature($protein_feature);
ok(@{ $translation->get_all_ProteinFeatures } == 1);

# reset ProteinFeature cache
$translation->{'protein_features'} = undef;


#
# test length() and seq()
#
my $seq = $translation->seq();
debug("Seq = $seq");
ok($seq);

debug("Lenth = " . $translation->length());
ok(length($seq) == $translation->length());


#
# test remove method
#

$multi->save('core', 'translation', 'translation_stable_id',
             'protein_feature', 'object_xref', 'identity_xref',
             'go_xref');

my $tl_count = count_rows($db, 'translation');
my $tlstable_count = count_rows($db, 'translation_stable_id');
my $pfeat_count = count_rows($db, 'protein_feature');


my $pfeat_minus = @{$translation->get_all_ProteinFeatures()};

$ta->remove($translation);

ok(!defined($translation->dbID));
ok(!defined($translation->adaptor()));

ok(count_rows($db, 'translation') == $tl_count - 1);
ok(count_rows($db, 'translation_stable_id') == $tlstable_count - 1);
ok(count_rows($db, 'protein_feature') == $pfeat_count - $pfeat_minus);

#
# Attribute handling for selenocystein
#

my $tr = $tra->fetch_by_stable_id( "ENST00000217347" );

$tr->edits_enabled(1);

my $sc = Bio::EnsEMBL::SeqEdit->new(-START   => 2,
                                    -END     => 2,
                                    -ALT_SEQ => 'U',
                                    -CODE    => '_selenocysteine',
                                    -NAME    => 'Selenocysteine');

$tr->translation->add_Attributes( $sc->get_Attribute() );

$sc->start(3);
$sc->end(3);

$tr->translation->add_Attributes( $sc->get_Attribute() );

$sc->start(4);
$sc->end(4);

$tr->translation->add_Attributes( $sc->get_Attribute() );

my $tlseq = $tr->translate->seq();

debug( "UUU inserted: ".$tlseq );
ok( $tlseq =~ /^.UUU/ );

#
# store and retrieve by lazy load
#

$multi->hide( "core", "translation_attrib" );

my $tl = $tr->translation();
my $attrAdaptor = $db->get_AttributeAdaptor();

$attrAdaptor->store_on_Translation($tl->dbID, $tl->get_all_Attributes);

$tr = $tra->fetch_by_stable_id( "ENST00000217347" );

$tr->edits_enabled(1);

$tlseq = $tr->translate->seq();
ok( $tlseq =~ /^.UUU/ );

$multi->restore();


#
# Check if this was not caching artefact
#  No selenos should occur here
#
$tr = $tra->fetch_by_stable_id( "ENST00000217347" );

$tlseq = $tr->translate->seq();
ok( $tlseq !~ /^.UUU/ );



# test the fetch_all_by_Transcript_list method
my $tr2 = $tra->fetch_by_stable_id('ENST00000252021');

my @tls = @{$ta->fetch_all_by_Transcript_list([$tr,$tr2])};

ok(@tls == 2);



# test that translation attribs are stored when translation is stored
# check that attributes are stored when transcript is stored

$tr = $tra->fetch_by_stable_id( "ENST00000217347" );

$tl = $tr->translation();

# unstore the translation so it can be stored again

$tl->adaptor(undef);
$tl->dbID(undef);


$multi->hide('core', 'transcript', 'translation_attrib', 'translation',
             'translation_stable_id');


# add a couple of attributes to the translation

$sc = Bio::EnsEMBL::SeqEdit->new(-START   => 2,
                                 -END     => 2,
                                 -ALT_SEQ => 'U',
                                 -CODE    => '_selenocysteine',
                                 -NAME    => 'Selenocysteine');

$tl->add_Attributes( $sc->get_Attribute() );

$sc->start(3);
$sc->end(3);

$tl->add_Attributes( $sc->get_Attribute() );

$ta->store($tl, $tr->dbID());

ok(count_rows($db, 'translation_attrib') == 2);

$multi->restore('core');


