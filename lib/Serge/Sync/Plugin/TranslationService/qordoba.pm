# ABSTRACT: Qordoba (https://qordoba.com/) synchronization plugin for Serge

package Serge::Sync::Plugin::TranslationService::qordoba;
use parent Serge::Sync::Plugin::Base::TranslationService, Serge::Interface::SysCmdRunner;

use strict;

use Serge::Util qw(subst_macros);
use version;

our $VERSION = qv('0.900.0');

sub name {
    return 'Qordoba translation software (https://qordoba.com/) synchronization plugin';
}

sub init {
    my $self = shift;

    $self->SUPER::init(@_);

    $self->{optimizations} = 1; # set to undef to disable optimizations

    $self->merge_schema({
        config_file      => 'STRING',
        debug            => 'BOOLEAN'
    });
}

sub validate_data {
    my ($self) = @_;

    $self->SUPER::validate_data;

    $self->{data}->{config_file} = subst_macros($self->{data}->{config_file});
    $self->{data}->{debug} = subst_macros($self->{data}->{debug});

    die "'config_file' not defined" unless defined $self->{data}->{config_file};
    die "'config_file', which is set to '$self->{data}->{config_file}', does not point to a valid file.\n" unless -f $self->{data}->{config_file};
}

sub run_qordoba_cli {
    my ($self, $action) = @_;

    $ENV{'QORDOBA_CONFIG'} = $self->{data}->{config_file};

    my $command = $action;

    $command = 'qor '.$command;

    if ($self->{data}->{debug}) {
        $command .= ' --debug ';
    }

    print "Running '$command'...\n";
    return $self->run_cmd($command, $capture);
}

sub pull_ts {
    my ($self, $langs) = @_;

    my $action = 'pull --replace --force';

    if ($langs) {
        my @qordoba_langs = map {$self->get_qordoba_lang($_)} @$langs;

        my $langs_as_string = join(',', @qordoba_langs);

        $action .= ' -l '.$langs_as_string;
    }

    return $self->run_qordoba_cli($action, $langs);
}

sub push_ts {
    my ($self, $langs) = @_;

    my $action = 'push --update';

    $self->run_qordoba_cli($action, $langs);
}

sub get_qordoba_lang {
    my ($self, $lang) = @_;

    $lang =~ s/-(\w+)$/'_'.uc($1)/e; # convert e.g. 'pt-br' to 'pt_BR'

    return $lang;
}

1;