package Serge::Engine::Plugin::google_translate;
use parent Serge::Plugin::Base::Callback;

use strict;
use utf8;

use Serge::Util qw(subst_macros);

sub name {
    return "Google translations plugin";
}

#  Examples:
#
#  Set (or replace existing) extra comment for the entire item (all language-specific units);
#  Text is optional. using just `@` clears the extra comment
#  @ [Text]
#
#  Append extra comment paragraph (`\n\n` + text) for the entire item (all language-specific units)
#  + <Text>
#
#  Add (append) `#tag1` to the end of the text; remove `#tag2`
#  #tag1 -#tag2
#
#  Skip string (mark as skipped in Serge database and remove from all .po files)
#  @skip

#  Rewrite all translations for the same string string with the provided translation value.
#  If translation is empty, this will simply remove the translation
#  @rewrite_all

#  Rewrite all translations for the same string string with the provided value
#  and mark translations as fuzzy. If the translation is empty, this has the same effect
#  as @rewrite_all (because empty translations can't be fuzzy)
#  @rewrite_all_as_fuzzy

sub init {
    my $self = shift;

    $self->SUPER::init(@_);

    $self->merge_schema({
        api_key                              => 'STRING'
    });

    $self->add({
        get_translation => \&get_translation
    });
}

sub validate_data {
    my ($self) = @_;

    $self->SUPER::validate_data;

    die "Google api key is not defined" unless exists $self->{data}->{api_key};

    eval('use WWW::Google::Translate;');
    die "ERROR: To use the google_translate plugin, please install WWW::Google::Translate module (run 'cpan WWW::Google::Translate')\n" if $@;
}

sub get_translation {
    my ($self, $string, $context, $namespace, $filepath, $lang, $disallow_similar_lang, $item_id, $key) = @_;

    my $source_lang = $self->{parent}->{source_language};

    my $source_locale = $self->language_from_lang($source_lang);
    my $target_locale = $self->language_from_lang($lang);

    my $wgt = WWW::Google::Translate->new(
        {   key            => $self->{data}->{api_key},
            default_source => $source_locale,
            default_target => $target_locale
        }
    );

    my $r = $wgt->translate( { q => $string } );

    for my $trans_rh (@{ $r->{data}->{translations} })
    {
        my $translation = $trans_rh->{translatedText};
        my $fuzzy = 1;
        my $comment = 'Google translate';
        my $need_save = 1;

        return ($translation, $fuzzy, $comment, $need_save);
    }

    return ('', undef, undef, undef);
}

sub language_from_lang {
    my ($self, $language) = @_;
    $language =~ s/(-.+?)(-.+)?$/uc($1).$2/e; # convert e.g. 'pt-br-Whatever' to 'pt-BR-Whatever'
    return $language;
}

1;