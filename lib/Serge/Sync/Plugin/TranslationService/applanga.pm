# ABSTRACT: Applanga (https://applanga.com) synchronization plugin for Serge

package Serge::Sync::Plugin::TranslationService::applanga;
use parent Serge::Sync::Plugin::Base::TranslationService, Serge::Interface::SysCmdRunner;

use strict;

use Serge::Util qw(subst_macros);
use version;

our $VERSION = qv('0.900.0');

sub name {
    return 'Applanga translation software (https://applanga.com) synchronization plugin';
}

sub init {
    my $self = shift;

    $self->SUPER::init(@_);

    $self->{optimizations} = 1; # set to undef to disable optimizations

    $self->merge_schema({
        config_path      => 'STRING'
    });
}

sub validate_data {
    my ($self) = @_;

    $self->SUPER::validate_data;

    $self->{data}->{config_path} = subst_macros($self->{data}->{config_path});

    die "'config_path' not defined" unless defined $self->{data}->{config_path};
    die "'config_path', which is set to '$self->{data}->{config_path}', does not point to a valid folder.\n" unless -d $self->{data}->{config_path};
}

sub run_applanga_cli {
    my ($self, $action) = @_;

    $ENV{'APPLANGA_CONFIG'} = $self->{data}->{config_path};

    my $command = $action;

    $command = 'applanga '.$command;

    print "Running '$command'...\n";
    return $self->run_cmd($command);
}

sub pull_ts {
    my ($self, $langs) = @_;

    return $self->run_applanga_cli('pull');
}

sub push_ts {
    my ($self, $langs) = @_;

    my $action = 'push --force';

    $self->run_applanga_cli($action);
}

1;