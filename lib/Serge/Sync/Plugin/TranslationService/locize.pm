# ABSTRACT: Locize (https://locize.com/ synchronization plugin for Serge

package Serge::Sync::Plugin::TranslationService::locize;
use parent Serge::Sync::Plugin::Base::TranslationService, Serge::Interface::SysCmdRunner;

use strict;

use Serge::Util qw(subst_macros);
use File::Find qw(find);
use File::Spec::Functions qw(catfile abs2rel);
use version;

our $VERSION = qv('0.900.0');

sub name {
    return 'Locize translation software (https://locize.com/) synchronization plugin';
}

sub init {
    my $self = shift;

    $self->SUPER::init(@_);

    $self->{optimizations} = 1; 

    $self->merge_schema({
        config_file         => 'STRING',
        format              => 'STRING',
        path                => 'STRING',
        languages           => 'ARRAY'
    });
}

sub validate_data {
    my ($self) = @_;

    $self->SUPER::validate_data;

    $self->{data}->{config_file} = subst_macros($self->{data}->{config_file});
    $self->{data}->{format} = subst_macros($self->{data}->{format});
    $self->{data}->{languages} = subst_macros($self->{data}->{languages});
    $self->{data}->{path} = subst_macros($self->{data}->{path});

    die "'config_file' not defined" unless defined $self->{data}->{config_file};
    die "'config_file', which is set to '$self->{data}->{config_file}', does not point to a valid file.\n" unless -f $self->{data}->{config_file};

    die "'format' not defined" unless defined $self->{data}->{format};

    die "'path', which is set to '$self->{data}->{path}', does not point to a valid folder." unless -d $self->{data}->{path};

    $self->{data}->{cleanup_mode} = 0 unless defined $self->{data}->{cleanup_mode};

    if (!defined $self->{data}->{languages} or scalar(@{$self->{data}->{languages}}) == 0) {
        die "the list of languages is empty";
    }
}

sub pull_ts {
    my ($self, $langs) = @_;

    if ($langs) {
        my $langs_to_push = $self->get_langs($langs);

        foreach my $lang (@$langs_to_push) {
            my $cli_return = $self->locize_download($lang);

            if ($cli_return != 0) {
                return $cli_return;
            }
        }
    } else {
        my $cli_return = $self->locize_download();

        if ($cli_return != 0) {
            return $cli_return;
        }
    }

    return 0;
}

sub push_ts {
    my ($self, $langs) = @_;

    if ($langs) {
        my $langs_to_push = $self->get_langs($langs);

        foreach my $lang (@$langs_to_push) {
            my $cli_return = $self->locize_sync($lang);

            if ($cli_return != 0) {
                return $cli_return;
            }
        }
    } else {
        my $cli_return = $self->locize_sync();

        if ($cli_return != 0) {
            return $cli_return;
        }
    }

    return 0;
}

sub locize_download {
    my ($self, $lang) = @_;

    my $action = 'download';

    my $download_path = $self->{data}->{path};
    $download_path = catfile($self->{data}->{path}, $lang) if $lang;

    $action .= ' --path '.$download_path;
    $action .= ' --language '.$self->get_locize_lang($lang) if $lang;

    return $self->run_locize_cli($action);
}

sub locize_sync {
    my ($self, $lang) = @_;

    my $action = 'sync';

    $action .= ' --path '.$self->{data}->{path};
    $action .= ' --language '.$self->get_locize_lang($lang) if $lang;
    $action .= ' --update-values true --reference-language-only false';

    return $self->run_locize_cli($action);
}

sub run_locize_cli {
    my ($self, $action) = @_;

    my $command = $action;

    $command .= ' --config-path '.$self->{data}->{config_file};
    $command .= ' --format '.$self->{data}->{format};

    $command = 'locize '.$command;
    print "Running '$command'...\n";
    return $self->run_cmd($command);
}

sub get_locize_lang {
    my ($self, $lang) = @_;

    $lang =~ s/-(\w+)$/'_'.uc($1)/e; # convert e.g. 'pt-br' to 'pt_BR'

    return $lang;
}

sub get_langs {
    my ($self, $langs) = @_;

    if (!$langs) {
        $langs = $self->{data}->{languages};
    }

    return $langs;
}


1;