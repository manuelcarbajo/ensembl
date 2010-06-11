# Schema for internal-external database mappings (xrefs)


################################################################################
#
# General external annotation.

CREATE TABLE xref (

  xref_id                     int unsigned not null auto_increment,
  accession                   varchar(255) not null,
  version                     int unsigned,
  label                       varchar(255),
  description                 text,
  source_id                   int unsigned not null,
  species_id                  int unsigned not null,
  info_type                   ENUM( 'PROJECTION', 'MISC', 'DEPENDENT',
                                    'DIRECT', 'SEQUENCE_MATCH',
                                    'INFERRED_PAIR', 'PROBE',
                                    'UNMAPPED', 'COORDINATE_OVERLAP' ),
  info_text	              VARCHAR(255),
  dumped                      INT UNSIGNED,

  PRIMARY KEY (xref_id),
  UNIQUE acession_idx(accession,source_id,species_id)

) COLLATE=latin1_swedish_ci TYPE=InnoDB;

################################################################################

CREATE TABLE primary_xref (

  xref_id                     int unsigned not null,
  sequence                    mediumtext,
  sequence_type               enum('dna','peptide'),
  status                      enum('experimental','predicted'),

  PRIMARY KEY (xref_id)

) COLLATE=latin1_swedish_ci TYPE=InnoDB;

################################################################################

CREATE TABLE dependent_xref (

  object_xref_id              int unsigned,
  master_xref_id              int unsigned not null,
  dependent_xref_id           int unsigned not null,
  linkage_annotation          varchar(255),
  linkage_source_id           int unsigned not null,

  KEY master_idx(master_xref_id),
  KEY dependent_idx(dependent_xref_id),
  KEY object_id(object_xref_id)

) COLLATE=latin1_swedish_ci TYPE=InnoDB;





################################################################################

CREATE TABLE synonym (

  xref_id                     int unsigned not null,
  synonym                     varchar(255),

  KEY xref_idx(xref_id),
  KEY synonym_idx(synonym)

) COLLATE=latin1_swedish_ci TYPE=InnoDB;

################################################################################

CREATE TABLE source (

  source_id                   int unsigned not null auto_increment,
  name                        varchar(255) not null,
  status                      enum('KNOWN','XREF','PRED','ORTH','PSEUDO','NOIDEA') not null default 'NOIDEA',
  source_release              varchar(255),
  download                    enum('Y', 'N') default 'Y',
  ordered                     int unsigned not null, 
  priority                    int unsigned default 1,
  priority_description        varchar(40) default "",
   
  PRIMARY KEY (source_id),
  KEY name_idx(name) 

) COLLATE=latin1_swedish_ci TYPE=InnoDB;

################################################################################

CREATE TABLE source_url (

  source_url_id               int unsigned not null auto_increment,
  source_id                   int unsigned not null,
  species_id                  int unsigned not null,
  url                         mediumtext,
  release_url                 mediumtext,
  checksum                    varchar(1025),
  file_modified_date          datetime,
  upload_date                 datetime,
  parser                      varchar(255),

  PRIMARY KEY (source_url_id),
  KEY source_idx(source_id)

) COLLATE=latin1_swedish_ci TYPE=InnoDB;

################################################################################

CREATE TABLE gene_direct_xref (

  general_xref_id             int unsigned not null,
  ensembl_stable_id           varchar(255),
  linkage_xref                varchar(255),

  KEY primary_idx(general_xref_id),
  KEY ensembl_idx(ensembl_stable_id)

) COLLATE=latin1_swedish_ci TYPE=InnoDB;


CREATE TABLE transcript_direct_xref (

  general_xref_id             int unsigned not null,
  ensembl_stable_id           varchar(255),
  linkage_xref                varchar(255),

  KEY primary_idx(general_xref_id),
  KEY ensembl_idx(ensembl_stable_id)

) COLLATE=latin1_swedish_ci TYPE=InnoDB;

CREATE TABLE translation_direct_xref (

  general_xref_id             int unsigned not null,
  ensembl_stable_id           varchar(255),
  linkage_xref                varchar(255),

  KEY primary_idx(general_xref_id),
  KEY ensembl_idx(ensembl_stable_id)

) COLLATE=latin1_swedish_ci TYPE=InnoDB;

################################################################################

CREATE TABLE species (

  species_id                  int unsigned not null,
  taxonomy_id                 int unsigned not null,
  name                        varchar(255) not null,
  aliases                     varchar(255),

  KEY species_idx (species_id),
  KEY taxonomy_idx(taxonomy_id),
  UNIQUE KEY species_taxonomy_idx(species_id,taxonomy_id),
  KEY name_idx(name)

) COLLATE=latin1_swedish_ci TYPE=InnoDB;

################################################################################

CREATE TABLE interpro (

  interpro               varchar(255) not null,
  pfam                   varchar(255) not null,
  dbtype                 enum ('PROSITE','PFAM','PREFILE','PROFILE','TIGRFAMs','PRINTS','PIRSF','SMART','SSF')  not null

) COLLATE=latin1_swedish_ci TYPE=InnoDB;

################################################################################

CREATE TABLE pairs (

  source_id			 int unsigned not null,
  accession1                     varchar(255) not null,
  accession2                     varchar(255) not null

) COLLATE=latin1_swedish_ci TYPE=InnoDB;
################################################################################

-- Table for coordinate-based Xrefs, based
-- on the knownGenes table from UCSC.

CREATE TABLE coordinate_xref (
  coord_xref_id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  source_id     INT UNSIGNED NOT NULL,
  species_id    INT UNSIGNED NOT NULL,
  accession     VARCHAR(255) NOT NULL,
  chromosome    VARCHAR(255) NOT NULL,
  strand        TINYINT(2) NOT NULL,
  txStart       INT(10) NOT NULL,
  txEnd         INT(10) NOT NULL,
  cdsStart      INT(10),
  cdsEnd        INT(10),
  exonStarts    TEXT NOT NULL,
  exonEnds      TEXT NOT NULL,

  UNIQUE KEY coord_xref_idx(coord_xref_id),
  INDEX start_pos_idx(species_id, chromosome, strand, txStart),
  INDEX end_pos_idx(species_id, chromosome, strand, txEnd)
) COLLATE=latin1_swedish_ci TYPE=InnoDB;

################################################################################
################################################################################

-- new tables for new mapper code

CREATE TABLE mapping (
  job_id         INT UNSIGNED,
  type           enum('dna','peptide','UCSC'), # not sure about UCSC
  command_line   text,
  percent_query_cutoff    INT UNSIGNED,
  percent_target_cutoff   INT UNSIGNED,
  method         VARCHAR(255),
  array_size     INT UNSIGNED

) COLLATE=latin1_swedish_ci TYPE=InnoDB;

CREATE TABLE mapping_jobs (
  root_dir          text,
  map_file          VARCHAR(255),
  status            enum('SUBMITTED','FAILED','SUCCESS'),
  out_file          VARCHAR(255),
  err_file          VARCHAR(255),
  array_number      INT UNSIGNED,
  job_id            INT UNSIGNED,
  failed_reason     VARCHAR(255),
  object_xref_start INT UNSIGNED,
  object_xref_end   INT UNSIGNED

) COLLATE=latin1_swedish_ci TYPE=InnoDB;

CREATE TABLE gene_transcript_translation (

  gene_id			INT UNSIGNED NOT NULL,
  transcript_id			INT UNSIGNED NOT NULL,
  translation_id		INT UNSIGNED,
  PRIMARY KEY (transcript_id),
  INDEX gene_idx (gene_id),
  INDEX translation_idx (translation_id)

) COLLATE=latin1_swedish_ci TYPE=InnoDB;

CREATE TABLE core_database (
  port		INT UNSIGNED,
  user          VARCHAR(16),
  pass          VARCHAR(16),
  dbname        VARCHAR(16),
  xref_dir      text,
  core_dir      text

) COLLATE=latin1_swedish_ci TYPE=InnoDB;
  


CREATE TABLE havana_status (

  stable_id    VARCHAR(128),
  status       enum('KNOWN','NOVEL','PUTATIVE','PREDICTED','KNOWN_BY_PROJECTION','UNKNOWN'),
  UNIQUE KEY status_idx(stable_id)

) COLLATE=latin1_swedish_ci TYPE=InnoDB;

#
# Try to keep the status in the correct order
#   it will make it easier to see what is happening
#

CREATE TABLE process_status (
  id            INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  status	enum('xref_created','parsing_started','parsing_finished','xref_fasta_dumped','core_fasta_dumped',
                     'mapping_submitted','mapping_finished','mapping_processed',
                     'core_data_loaded','direct_xrefs_parsed',
                     'prioritys_flagged','processed_pairs','official_naming_done',
		     'coordinate_xrefs_started','coordinate_xref_finished',
                     'tests_started','tests_failed','tests_finished',
                     'core_loaded','display_xref_done','gene_description_done'),
  date          DATETIME NOT NULL,
  PRIMARY KEY (id)
) COLLATE=latin1_swedish_ci TYPE=InnoDB;


                     

################################################################################
################################################################################
################################################################################

-- Incorporated but modified core tables

CREATE TABLE gene_stable_id (

  internal_id                 INT UNSIGNED NOT NULL,
  stable_id                   VARCHAR(128) NOT NULL,

  PRIMARY KEY (stable_id),
  INDEX internal_idx (internal_id)

) COLLATE=latin1_swedish_ci TYPE=InnoDB;

CREATE TABLE transcript_stable_id (

  internal_id                 INT UNSIGNED NOT NULL,
  stable_id                   VARCHAR(128) NOT NULL,

  PRIMARY KEY (stable_id),
  INDEX internal_idx (internal_id)

) COLLATE=latin1_swedish_ci TYPE=InnoDB;

CREATE TABLE translation_stable_id (

  internal_id                 INT UNSIGNED NOT NULL,
  stable_id                   VARCHAR(128) NOT NULL,

  PRIMARY KEY (stable_id),
  INDEX internal_idx (internal_id)

) COLLATE=latin1_swedish_ci TYPE=InnoDB;




CREATE TABLE object_xref (

  object_xref_id              INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  ensembl_id                  INT(10) UNSIGNED NOT NULL,
  ensembl_object_type         ENUM('RawContig', 'Transcript', 'Gene',
                                   'Translation')
                              NOT NULL,
  xref_id                     INT UNSIGNED NOT NULL,
  linkage_annotation          VARCHAR(255) DEFAULT NULL,
  linkage_type                ENUM( 'PROJECTION', 'MISC', 'DEPENDENT',
                                    'DIRECT', 'SEQUENCE_MATCH',
                                    'INFERRED_PAIR', 'PROBE',
                                    'UNMAPPED', 'COORDINATE_OVERLAP' ),
  ox_status                   ENUM( 'DUMP_OUT','FAILED_PRIORITY', 'FAILED_CUTOFF', 'NO_DISPLAY')  NOT NULL DEFAULT 'DUMP_OUT',
-- set ox_status to 0 if non used priority_xref or failed cutoff
  unused_priority             INT UNSIGNED,
  master_xref_id              INT UNSIGNED DEFAULT NULL,

  UNIQUE (ensembl_object_type, ensembl_id, xref_id, ox_status),
  KEY oxref_idx (object_xref_id, xref_id, ensembl_object_type, ensembl_id),
  KEY xref_idx (xref_id, ensembl_object_type)

) COLLATE=latin1_swedish_ci TYPE=InnoDB;


CREATE TABLE identity_xref (

  object_xref_id          INT(10) UNSIGNED NOT NULL,
  query_identity          INT(5),
  target_identity         INT(5),

  hit_start               INT,
  hit_end                 INT,
  translation_start       INT,
  translation_end         INT,
  cigar_line              TEXT,

  score                   DOUBLE,
  evalue                  DOUBLE,
--  analysis_id             SMALLINT UNSIGNED NOT NULL, # set in core not needed in xref

  PRIMARY KEY (object_xref_id)
--  KEY analysis_idx (analysis_id)

) COLLATE=latin1_swedish_ci TYPE=InnoDB;

CREATE TABLE go_xref (

  object_xref_id          INT(10) UNSIGNED DEFAULT '0' NOT NULL,
  linkage_type            ENUM('IC', 'IDA', 'IEA', 'IEP', 'IGI', 'IMP', 
                               'IPI', 'ISS', 'NAS', 'ND', 'TAS', 'NR', 'RCA',
			       'EXP', 'ISO', 'ISA', 'ISM', 'IGC' )
                          NOT NULL,
  source_xref_id          INT(10) UNSIGNED DEFAULT NULL,
  KEY (object_xref_id),
  KEY (source_xref_id),
  UNIQUE (object_xref_id, source_xref_id, linkage_type)

) COLLATE=latin1_swedish_ci TYPE=InnoDB;


CREATE TABLE meta (

  meta_id                     INT NOT NULL AUTO_INCREMENT,
  species_id                  INT UNSIGNED DEFAULT 1,
  meta_key                    VARCHAR(40) NOT NULL,
  meta_value                  VARCHAR(255) BINARY NOT NULL,
  date                        DATETIME NOT NULL,

  PRIMARY   KEY (meta_id),
  UNIQUE    KEY species_key_value_idx (meta_id, species_id, meta_key, meta_value),
            KEY species_value_idx (species_id, meta_value)

) COLLATE=latin1_swedish_ci TYPE=InnoDB;




