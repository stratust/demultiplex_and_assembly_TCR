#!/usr/bin/env perl
package MyApp {
    use MooseX::App qw(Color);
    use Log::Any '$log';

    has 'log' => (
        is            => 'ro',
        isa           => 'Log::Any::Proxy',
        required      => 1,
        default       => sub { Log::Any->get_logger },
        documentation => 'Keep Log::Any::App object',
    );

    __PACKAGE__->meta->make_immutable;
}

package MyApp::Foo {
    use feature qw(say);
    use MooseX::App::Command;
    extends 'MyApp';    # inherit log
    use MooseX::FileAttribute;
    use IO::Uncompress::AnyUncompress qw(anyuncompress $AnyUncompressError);
    use namespace::autoclean;
    use Data::Printer;
    use File::Find::Rule;
    use Bio::SeqIO;
    use File::Path qw(make_path);
    use IO::Compress::Gzip qw(gzip $GzipError);

    command_short_description q[This command is awesome];
    command_long_description q[This command is so awesome, yadda yadda yadda];

    has_file 'fastq_file_r1' => (
        traits        => ['AppOption'],
        cmd_type      => 'option',
        required      => 1,
        documentation => q[Very important option!],
    );

    has_file 'fastq_file_r2' => (
        traits        => ['AppOption'],
        cmd_type      => 'option',
        required      => 1,
        documentation => q[Very important option!],
    );


    has_file 'plate_barcode_file' => (
        traits        => ['AppOption'],
        cmd_type      => 'option',
        required      => 1,
        documentation => q[Very important option!],
    );


    has_file 'row_barcode_file' => (
        traits        => ['AppOption'],
        cmd_type      => 'option',
        required      => 1,
        documentation => q[Very important option!],
    );


    has_file 'column_barcode_file' => (
        traits        => ['AppOption'],
        cmd_type      => 'option',
        required      => 1,
        documentation => q[Very important option!],
    );


    has 'plate_barcode' => (
        is      => 'ro',
        isa     => 'HashRef',
        lazy    => 1,
        builder => '_build_plate_barcodes'
    );


    has 'row_barcode' => (
        is      => 'ro',
        isa     => 'HashRef',
        lazy    => 1,
        builder => '_build_row_barcodes'
    );


    has 'column_barcode' => (
        is      => 'ro',
        isa     => 'HashRef',
        lazy    => 1,
        builder => '_build_column_barcodes'
    );


    has_directory 'output_folder' => (
        traits        => ['AppOption'],
        cmd_type      => 'option',
        required      => 1,
        documentation => q[Very important option!],
    );


    sub create_output_fastq {
        my ($self, $file) = @_;
        my $z = IO::Compress::Gzip->new($file, {AutoClose => 1}) or die "gzip failed: $GzipError\n";
        my $out = Bio::SeqIO->new(-fh => $z, -format => 'fastq');
        return $out;
    }


    sub _build_plate_barcodes {
        my ( $self ) = @_;
        my %barcode_hash;

        open( my $fh, '<', $self->plate_barcode_file->stringify );
        while ( my $row = <$fh> ) {
            # chomp $row;
            $row =~ s/[\n\r]$//g;
            my @split_row = split("\t", $row);
            $barcode_hash{$split_row[0]} = $split_row[1];
        }

        return(\%barcode_hash);
    }


    sub _build_row_barcodes {
        my ( $self ) = @_;
        my %barcode_hash;

        open( my $fh, '<', $self->row_barcode_file->stringify );
        while ( my $row = <$fh> ) {
            # chomp $row;
            $row =~ s/[\n\r]$//g;
            my @split_row = split("\t", $row);
            $barcode_hash{$split_row[0]} = $split_row[1];
        }

        return(\%barcode_hash);
    }


    sub _build_column_barcodes {
        my ( $self ) = @_;
        my %barcode_hash;

        open( my $fh, '<', $self->column_barcode_file->stringify );
        while ( my $row = <$fh> ) {
            # chomp $row;
            $row =~ s/[\n\r]$//g;
            my @split_row = split("\t", $row);
            $barcode_hash{$split_row[0]} = $split_row[1];
        }

        return(\%barcode_hash);
    }


    sub read_fastq {
        my ( $self, $file ) = @_;
        my $fh = IO::Uncompress::AnyUncompress->new( $file, { AutoClose => 1, MultiStream => 1 } ) or die "Cannot open: $AnyUncompressError\n";
        my $in = Bio::SeqIO->new( -fh => $fh, -format => 'fastq' );
        return ( $in );
    }


    sub check_plate_row_barcode {
        my ( $self, $seq, $plate_barcodes_hash_ref, $row_barcodes_hash_ref ) = @_;

        my $seq_string = $seq->seq;
                                            #GA
        if ( $seq_string =~ m/^\S{2}(\S{5})(\S{2})(\S{5}).*/ ) {
            my $plate_barcode = $1;
            # my $GA = uc $2;
            my $row_barcode = $3;

            if ( $plate_barcodes_hash_ref->{$plate_barcode} and $row_barcodes_hash_ref->{$row_barcode} ) {

                return( $plate_barcodes_hash_ref->{$plate_barcode}, $row_barcodes_hash_ref->{$row_barcode});

            } elsif ($plate_barcodes_hash_ref->{$plate_barcode} and !$row_barcodes_hash_ref->{$row_barcode}) {

                return( $plate_barcodes_hash_ref->{$plate_barcode}, 0)

            } elsif (!$plate_barcodes_hash_ref->{$plate_barcode} and $row_barcodes_hash_ref->{$row_barcode} ) {

                return( 0, $row_barcodes_hash_ref->{$row_barcode});

            } else {
                return(0, 0);
            }

        } else {
            return(0, 0);
        }
    }


    sub check_column_barcode {
        my ( $self, $seq, $column_barcodes_hash_ref ) = @_;

        my $seq_string = $seq->seq;
        my $column_barcode;

        if ( $seq_string =~ m/^\S{2}(\S{5}).*/ ) {
            $column_barcode = $1;
        } else {
            die "Critical Error: regex to get the column barcodes failed";
        }

        if ( $column_barcodes_hash_ref->{$column_barcode} ) {
            return $column_barcodes_hash_ref->{$column_barcode};
        } else {
            return 0;
        }

    }


    sub demultiplex_fastq {
        my ( $self ) = @_;

        my $fastq_r1 = $self->read_fastq( $self->fastq_file_r1->stringify );
        my $fastq_r2 = $self->read_fastq( $self->fastq_file_r2->stringify );

        my $plate_barcodes_hash_ref  = $self->plate_barcode;
        my $row_barcodes_hash_ref    = $self->row_barcode;
        my $column_barcodes_hash_ref = $self->column_barcode;


        my $output_dir = $self->output_folder->stringify;
        # my $output_dir = $self->output_folder->stringify . "/demultiplexed_data";
        make_path( $output_dir );

        while ( my $r1 = $fastq_r1->next_seq ) {
            p $r1->id;

            my $r2 = $fastq_r2->next_seq;
            my ( $info_plate_r1,  $info_plate_r2 );
            my ( $info_row_r1,    $info_row_r2 );
            my ( $info_column_r1, $info_column_r2 );

            ( $info_plate_r1, $info_row_r1 ) = $self->check_plate_row_barcode( $r1, $plate_barcodes_hash_ref, $row_barcodes_hash_ref );
            $info_column_r2 = $self->check_column_barcode( $r2, $column_barcodes_hash_ref );

            ( $info_plate_r2, $info_row_r2 ) = $self->check_plate_row_barcode( $r2, $plate_barcodes_hash_ref, $row_barcodes_hash_ref );
            $info_column_r1 = $self->check_column_barcode( $r1, $column_barcodes_hash_ref );

            if (    ( ( $info_plate_r1 and $info_row_r1 ) and $info_column_r2 )
                and ( ( !$info_plate_r2 and !$info_row_r2 ) and ( !$info_column_r1 ) ) )
            {

                my $output_r1_filename = $output_dir . "/" . $info_plate_r1 . "_" . $info_row_r1 . "_" . $info_column_r2 . "_L001_R1_001.fastq";
                my $output_r2_filename = $output_dir . "/" . $info_plate_r1 . "_" . $info_row_r1 . "_" . $info_column_r2 . "_L001_R2_001.fastq";

#                 my $out1 = $self->create_output_fastq( $output_r1_filename );
                # my $out2 = $self->create_output_fastq( $output_r2_filename );

                my $out1 = Bio::SeqIO->new( -file => ">>$output_r1_filename", -format => "fastq" );
                my $out2 = Bio::SeqIO->new( -file => ">>$output_r2_filename", -format => "fastq" );

                $out1->write_seq( $r1 );
                $out2->write_seq( $r2 );

            }
            elsif ( ( ( !$info_plate_r1 and !$info_row_r1 ) and !$info_column_r2 )
                and ( ( $info_plate_r2 and $info_row_r2 ) and ( $info_column_r1 ) ) )
            {
                my $output_r1_filename = $output_dir . "/" . $info_plate_r2 . "_" . $info_row_r2 . "_" . $info_column_r1 . "_L001_R1_001.fastq";
                my $output_r2_filename = $output_dir . "/" . $info_plate_r2 . "_" . $info_row_r2 . "_" . $info_column_r1 . "_L001_R2_001.fastq";

#                 my $out1 = $self->create_output_fastq( $output_r1_filename );
                # my $out2 = $self->create_output_fastq( $output_r2_filename );

                my $out1 = Bio::SeqIO->new( -file => ">>$output_r1_filename", -format => "fastq" );
                my $out2 = Bio::SeqIO->new( -file => ">>$output_r2_filename", -format => "fastq" );

                $out1->write_seq( $r2 );
                $out2->write_seq( $r1 );

            } else {

                my $output_r1_filename = $output_dir . "/Undetermined_R1.fastq";
                my $output_r2_filename = $output_dir . "/Undetermined_R2.fastq";

#                 my $out1 = $self->create_output_fastq( $output_r1_filename );
                # my $out2 = $self->create_output_fastq( $output_r2_filename );

                my $out1 = Bio::SeqIO->new( -file => ">>$output_r1_filename", -format => "fastq" );
                my $out2 = Bio::SeqIO->new( -file => ">>$output_r2_filename", -format => "fastq" );

                $out1->write_seq( $r1 );
                $out2->write_seq( $r2 );


            }
        }
    }


    sub run {
        my ($self) = @_;

        $self->demultiplex_fastq();

    }

    __PACKAGE__->meta->make_immutable;
}

use MyApp;
use Log::Any::App '$log', -screen => 1;    # turn off screen logging explicitly
MyApp->new_with_command->run();

