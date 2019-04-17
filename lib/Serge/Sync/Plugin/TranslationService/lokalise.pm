# ABSTRACT: Lokalise (https://lokalise.co/) synchronization plugin for Serge

package Serge::Sync::Plugin::TranslationService::lokalise;
use parent Serge::Sync::Plugin::Base::TranslationService, Serge::Interface::SysCmdRunner;

use strict;

use File::Find qw(find);
use File::Spec::Functions qw(catfile abs2rel);
use Serge::Util qw(subst_macros);
use version;

our $VERSION = qv('0.900.0');

sub name {
    return 'Lokalise translation software (https://lokalise.co/) synchronization plugin';
}

sub init {
    my $self = shift;

    $self->SUPER::init(@_);

    $self->{optimizations} = 1; 

    $self->merge_schema({
        config_file    => 'STRING',
        cleanup_mode   => 'BOOLEAN',
        root_directory => 'STRING',
        languages      => 'ARRAY',
        file_mask      => 'STRING',
        file_format    => 'STRING'
    });
}

sub validate_data {
    my ($self) = @_;

    $self->SUPER::validate_data;

    $self->{data}->{config_file} = subst_macros($self->{data}->{config_file});
    $self->{data}->{cleanup_mode} = subst_macros($self->{data}->{cleanup_mode});
    $self->{data}->{languages} = subst_macros($self->{data}->{languages});
    $self->{data}->{file_mask} = subst_macros($self->{data}->{file_mask});
    $self->{data}->{file_format} = subst_macros($self->{data}->{file_format});

    die "'config_file' not defined" unless defined $self->{data}->{config_file};
    die "'config_file', which is set to '$self->{data}->{config_file}', does not point to a valid file.\n" unless -f $self->{data}->{config_file};

    die "'file_mask' not defined" unless defined $self->{data}->{file_mask};
    die "'file_format' not defined" unless defined $self->{data}->{file_format};

    $self->{data}->{cleanup_mode} = 0 unless defined $self->{data}->{cleanup_mode};

    if (!defined $self->{data}->{languages} or scalar(@{$self->{data}->{languages}}) == 0) {
        die "the list of languages is empty";
    }
}

sub run_lokalise_cli {
    my ($self, $action) = @_;

    my $command = ' --config '.$self->{data}->{config_file}.' '.$action;

    $command = 'lokalise '.$command;
    print "Running '$command'...\n";
    return $self->run_cmd($command);
}

sub get_lokalise_lang {
    my ($self, $lang) = @_;

    $lang =~ s/-(\w+)$/'-'.uc($1)/e; # convert e.g. 'pt-br' to 'pt-BR'

    return $lang;
}

sub pull_ts {
    my ($self, $langs) = @_;

    my $action = 'export --type '.$self->{data}->{file_format};
    $action .= ' --use_original 1';
    $action .= ' --unzip_to '.$self->{data}->{root_directory};

    if ($langs) {
        my @lokalise_langs = map {$self->get_lokalise_lang($_)} @$langs;

        my $langs_as_string = join(',', @lokalise_langs);

        $action .= ' --langs '.$langs_as_string;
    }

    return $self->run_lokalise_cli($action);
}

sub push_ts {
    my ($self, $langs) = @_;

    my $langs_to_push = $self->get_langs($langs);

    foreach my $lang (@$langs_to_push) {
        my $action = 'import';

        my $directory = catfile($self->{data}->{root_directory}, $lang);
        my $file_mask = catfile($directory, $self->{data}->{file_mask});

        $action .= ' --file '.$file_mask.' --lang_iso '.$self->get_lokalise_lang($lang);
        $action .= ' --replace 1 --fill_empty 0 --distinguish 1';

        my $cli_return = $self->run_lokalise_cli($action, ());

        if ($cli_return != 0) {
            return $cli_return;
        }
    }

    return 0;
}

sub get_langs {
    my ($self, $langs) = @_;

    if (!$langs) {
        $langs = $self->{data}->{languages};
    }

    return $langs;
}

1;