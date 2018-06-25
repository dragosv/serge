package Serge::Engine::Plugin::reuse_translations;
use parent Serge::Plugin::Base::Callback;

use strict;
use utf8;

use Serge::Util qw(subst_macros);

sub name {
    return "Reuse translations plugin";
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
        reuse_uncertain                      => 'BOOLEAN',
        reuse_as_fuzzy                       => 'BOOLEAN',
        reuse_as_not_fuzzy                   => 'BOOLEAN',
        reuse_as_fuzzy_default               => 'BOOLEAN',
        similar_languages                    => 'ARRAY',
        lang_matches                         => 'ARRAY',
        lang_doesnt_match                    => 'ARRAY',
        string_matches                       => 'ARRAY',
        string_doesnt_match                  => 'ARRAY',
        translation_matches                  => 'ARRAY',
        translation_doesnt_match             => 'ARRAY',
        reuse_string_equal_translation       => 'BOOLEAN'
    });

    $self->add({
        get_translation => \&get_translation
    });
}

sub validate_data {
    my ($self) = @_;

    $self->SUPER::validate_data;

    $self->{data}->{reuse_uncertain} = 1 unless exists $self->{data}->{reuse_uncertain};
    $self->{data}->{reuse_as_fuzzy} = 1 unless exists $self->{data}->{reuse_as_fuzzy};
    $self->{data}->{reuse_as_not_fuzzy} = 1 unless exists $self->{data}->{reuse_as_not_fuzzy};
    $self->{data}->{reuse_as_fuzzy_default} = 1 unless exists $self->{data}->{reuse_as_fuzzy_default};
    $self->{data}->{reuse_string_equal_translation} = 1 unless exists $self->{data}->{reuse_string_equal_translation};
}

sub get_translation {
    my ($self, $string, $context, $namespace, $filepath, $lang, $disallow_similar_lang, $item_id, $key) = @_;

    # Find the best match from other files or namespaces
    my ($translation, $fuzzy, $comment, $multiple_variants) = $self->{db}->find_best_translation(
        $namespace, $filepath, $string, $context, $lang, $self->{job}->{reuse_orphaned}, $self->{job}->{reuse_uncertain}
    );

    if ($multiple_variants && !$self->{data}->{reuse_uncertain}) {
        print "Multiple translations found, won't reuse any because 'reuse_uncertain' mode is set to NO\n" if $self->{debug};
        # return now, otherwise the translation might be obtained in e.g. transform plugin
        # from a similar string that has just one translation variant
        return;
    }

    my $valid_translation = $self->check_translation($string, $context, $namespace, $filepath, $lang, $item_id, $key, $translation);

    if ($valid_translation) {
        if ($fuzzy) {
            # if the fuzzy flag is already set, always leave it as is,
            # even if the language is listed under `reuse_as_not_fuzzy` list
        } else {
            # the fuzzy flag is not set, but we might want to raise it here
            my $lang_as_fuzzy = is_flag_set($self->{data}->{reuse_as_fuzzy}, $lang);
            my $lang_as_not_fuzzy = is_flag_set($self->{data}->{reuse_as_not_fuzzy}, $lang);
            $fuzzy = 1 if $lang_as_fuzzy || ($self->{data}->{reuse_as_fuzzy_default} && !$lang_as_not_fuzzy);
        }
        return ($translation, $fuzzy, $comment, 1) if ($translation ne '' || $comment ne '');
    }

    # Otherwise, try to look for a translation from a similar language

    if (!$disallow_similar_lang && exists $self->{data}->{similar_languages}) {
        foreach my $rule (@{$self->{data}->{similar_languages}}) {
            if ($rule->{destination} eq $lang) {
                foreach my $source_lang (sort @{$rule->{source}}) {
                    # pass disallow_similar_lang = 1 to avoid infinite recursion
                    my ($translation, $fuzzy, $comment, $need_save) =
                        $self->get_translation($string, $context, $namespace, $filepath, $source_lang, 1, $item_id, $key);
                    # force fuzzy flag if $rule->{as_fuzzy} is true; otherwise, use the original fuzzy flag value
                    $fuzzy = $fuzzy || $rule->{as_fuzzy};
                    return ($translation, $fuzzy, $comment, 1) if ($translation ne '' || $comment ne '');
                }
            }
        }
    }
}

sub check_translation {
    my ($self, $string, $context, $namespace, $filepath, $lang, $item_id, $key, $translation) = @_;

    if (not $self->{data}->{reuse_string_equal_translation}) {
        return 0 unless $string != $translation;
    }

    return 0 unless $self->_check_statement($self->{data}->{lang_matches},         1,     $lang);
    return 0 unless $self->_check_statement($self->{data}->{lang_doesnt_match},    undef, $lang);
    
    return 0 unless $self->_check_statement($self->{data}->{string_matches},         1,   $string);
    return 0 unless $self->_check_statement($self->{data}->{string_doesnt_match},  undef, $string);

    return 0 unless $self->_check_statement($self->{data}->{translation_matches},      1,     $translation);
    return 0 unless $self->_check_statement($self->{data}->{translation_doesnt_match}, undef, $translation);

    return 1;
}

sub _check_statement {
    my ($self, $ruleset, $positive, $value) = @_;

    return 1 unless defined $ruleset;

    foreach my $rule (@$ruleset) {
        if ($value =~ m/$rule/s) {
            return $positive;
        }
    }
    return !$positive;
}

1;