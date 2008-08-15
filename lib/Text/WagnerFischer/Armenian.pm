package Text::WagnerFischer::Armenian;
use base qw( Text::WagnerFischer );

=head1 NAME

Text::WagnerFischer::Armenian - a subclass of Text::WagnerFischer for Armenian-language strings

=head1 SYNOPSIS

 use Text::WagnerFischer::Armenian qw( distance );
 use utf8;

 print distance("ձեռն", "ձեռան") . "\n";  
    # "dzerrn -> dzerran"; prints 1
 print distance("ձեռն", "ձերն") . "\n";  
    # "dzerrn -> dzern"; prints 0.5
 print distance("կինք", "կին") . "\n";
    # "kin" -> "kink'"; prints 0.5
 my @words = qw( զօրսն Զորս զզօրսն );
 my @distances = distance( "զօրս", @words );
 print "@distances\n";
    # "zors" -> "zorsn, Zors, zzorsn" 
    # prints "0.5 0.25 1"

 # Change the cost of a letter case substitution to 1
 my $edit_values = [ ( 0, 1, 1, 1, 0.5, 0.5, 1 ),  # string-beginning values
                     ( 0, 1, 1, 1, 0.5, 1, 1 ),  # string-beginning values
                     ( 0, 1, 1, 1, 0.5, 1, 0.5 ),  # string-beginning values
                   ];
print distance( "ձեռն", "Ձեռն" ) . "\n";
    # prints 1
=DESCRIPTION

This module implements the Wagner-Fischer distance algorithm modified
for Armenian strings.  The Armenian language has a number of
single-letter prefixes and suffixes which, while not changing the
basic meaning of the word, function as definite articles,
prepositions, or grammatical markers.  These changes, and letter
substitutions that represent vocalic equivalence, should be counted as
a smaller edit distance than a change that is a normal character
substitution.

The Armenian weight function recognizes four extra edit types:

            / a: x = y           (cost for letter match)
            | b: x = - or y = -  (cost for letter insertion/deletion)
w( x, y ) = | c: x != y          (cost for letter mismatch) 
            | d: x = X           (cost for case mismatch)
            | e: x ~ y           (cost for letter vocalic equivalence)
            | f: x = (z|y|ts) && y = - (or vice versa)
            |          (cost for grammatic prefix)
            | g: x = (n|k'|s|d) && y = - (or vice versa)
            \          (cost for grammatic suffix)

These distance weights can be changed, although the prefix/suffix part
of the algorithm currently requires that the distance weights be
specified three times (for the start, middle, and end of the string.)
The weight arrays can be passed in as the first argument to distance.  

=head1 BUGS

There are many cases of Armenian word equivalence that are not
perfectly handled by this; it is meant to be a rough heuristic for
comparing transcriptions of handwriting.  In particular, multi-letter
suffixes, and some orthographic equivalence e.g "o" -> "aw", are not
handled at all.

=head1 AUTHOR

Tara L Andrews, L<aurum@cpan.org>

=head1 SEE ALSO

"Text::WagnerFischer"

=cut

use utf8;
BEGIN
{
    use strict;
    use vars qw( @EXPORT_OK $VERSION %VocalicEquivalence @Prefixes @Suffixes 
                 $REFC $REFC_start $REFC_end );
    no warnings 'redefine';

    $VERSION = "0.01";

    *_min = \&Text::WagnerFischer::_min;
    @EXPORT_OK = qw( &distance );
    
    #
    # Set new default costs:
    #
    # WagnerFischer   :  equal, insert/delete, mismatch, 
    # LetterCaseEquiv :  same word, case mismatch
    # VocalicEquiv    :  letter that changed with pronunciation shift
    # PrefixAddDrop   :  same word, one has prefix e.g. preposition form "y-"
    # SuffixAddDrop   :  same word, one has suffix e.g. definite article "-n"
    $REFC = [ 0, 1, 1,  0.25, 0.5, 1, 1 ];   # mid-word: no pre/suffix
    $REFC_start = [ 0, 1, 1,  0.25, 0.5, 0.5, 1 ]; # there may be a prefix
    $REFC_end = [ 0, 1, 1,  0.25, 0.5, 1, 0.5 ];   # there may be a suffix

    %VocalicEquivalence = (
	'բ' => [ 'պ' ],
	'գ' => [ 'ք', 'կ' ],
	'դ' => [ 'տ' ],
	'ե' => [ 'է' ],
	'է' => [ 'ե' ],
	'թ' => [ 'տ' ],
	'լ' => [ 'ղ' ],
	'կ' => [ 'գ', 'ք' ],
	'ղ' => [ 'լ' ],
	'ո' => [ 'օ' ],
	'պ' => [ 'բ', 'փ' ],
	'ռ' => [ 'ր' ],
	'վ' => [ 'ւ' ],
	'տ' => [ 'դ', 'թ'],
	'ր' => [ 'ռ' ],
	'ւ' => [ 'վ' ],
	'փ' => [ 'պ', 'ֆ' ],
	'ք' => [ 'գ', 'կ' ],
	'օ' => [ 'ո' ],
	'ֆ' => [ 'փ' ],
            );

    @Prefixes = qw( զ ց յ );
    @Suffixes = qw( ն ս դ ք );
}

sub _am_weight
{
    my ($x,$y,$refc)=@_;

    if ($x eq $y) {
	# Simple case: exact match.
	return $refc->[0];
    } elsif( am_lc( $x ) eq am_lc( $y ) ) {
	# Almost as simple: case difference.
	return $refc->[3];   # Vocalic equivalence.
    }

    # Got this far?  We have to play games with prefixes, suffixes,
    # similar-letter substitution, and the like.

    # Downcase both of them.
    $x = am_lc( $x );
    $y = am_lc( $y );

    if ( ($x eq '-') or ($y eq '-') ) {
	# Are we dealing with a prefix or a suffix?
	# print STDERR "x is $x; y is $y;\n";
	if( grep( /(\Q$x\E|\Q$y\E)/, @Prefixes ) > 0 ) {
	    return $refc->[5];
	} elsif( grep( /(\Q$x\E|\Q$y\E)/, @Suffixes ) > 0 ) {
	    return $refc->[6];
	} else {
	    # Normal insert/delete
	    return $refc->[1];
	}
    } else {
	if( exists( $VocalicEquivalence{$x} ) ) {
	    # Same word, vocalic shift?
	    # N.B. This will mistakenly give less weight to a few genuinely
	    # different words, e.g. the verbs "գամ" vs. "կամ".  I can live with that.
	    my @equivs = @{$VocalicEquivalence{$x}};
	    my $val = grep (/$y/, @equivs ) ? $refc->[4] : $refc->[2];
	    return $val;
	} else {
	    return $refc->[2];
	}
    }

    return $value;
}

# Annoyingly, I need to copy this whole damn thing because I need to change
# the refc mid-stream.
sub distance {
    my ($refc,$s,@t)=@_;

    # Set up defaults.
    my $refc_start = $REFC_start;
    my $refc_mid = $REFC;
    my $refc_end = $REFC_end;
    
    if (!@t) {
	# Two args...
	if (ref($refc) ne "ARRAY") {
	    # the first of which is a string...
	    if (ref($s) ne "ARRAY") {
		# ...and the second of which is a string.
		# Use default refc set.
		$t[0]=$s;
		$s=$refc;
		$refc=$refc_mid;
	    } else {
		# ...one of which is an array.  Croak.
		require Carp;
		Carp::croak("Text::WagnerFischer: second string is needed");
	    }
	} else {
	    # one refc, and one string.  Croak.
	    require Carp;
	    Carp::croak("Text::WagnerFischer: second string is needed");
	}
    } elsif (ref($refc) ne "ARRAY") {
	# Three or more args, all strings.
	# Use default refc set.
	
	unshift @t,$s;
	$s=$refc;
	$refc=$refc_mid;
    } else {
	# A refc array and (presumably) some strings.
	# Do we have one or three refcs?
	if( ref( $refc->[0] ) ne "ARRAY" ) {
	    # We have one.  Use only this one.
	    $refc_start = $refc_end = $refc_mid = $refc;
	} elsif ( scalar( @$refc ) == 3 ) {
	    $refc_start = $refc->[0];
	    $refc_mid = $refc->[1];
	    $refc_end = $refc->[2];
	} else {
	    require Carp;
	    Carp::croak( "Text::WagnerFischer::Armenian: must pass either one or three refc arrays" );
	}
	$refc = $refc_mid;
    }
    
    my $n=length($s);
    my @result;
    
    foreach my $t (@t) {
	
	my @d;
	
	my $m=length($t);
	if(!$n) {push @result,$m*$refc->[1];next}
	if(!$m) {push @result,$n*$refc->[1];next}
	
	$d[0][0]=0;
	
	# Populate the zero row.
	# Cannot assume that blank vs. 1st letter is "add".  Might
	# be "prefix."
	my $f_i = substr($s,0,1);
	foreach my $i (1 .. $n) {$d[$i][0]=$i*_am_weight('-',$f_i,$refc_start);}
	my $f_j = substr($t,0,1);
	foreach my $j (1 .. $m) {$d[0][$j]=$j*_am_weight($f_j,'-',$refc_start);}
	
	foreach my $i (1 .. $n) {
	    my $s_i=substr($s,$i-1,1);
	    foreach my $j (1 .. $m) {
		# Switch to suffix refc if we are to end of either word.
		$refc = $refc_end if( $i == $n || $j == $m );
		my $t_i=substr($t,$j-1,1);
		
		$d[$i][$j]=_min($d[$i-1][$j]+_am_weight($s_i,'-',$refc),
				$d[$i][$j-1]+_am_weight('-',$t_i,$refc),
				$d[$i-1][$j-1]+_am_weight($s_i,$t_i,$refc));
	    }
	}
	
	my $r = $d[$n][$m];
	## Round up to get an integer result.
	## On second thought, don't.
	# if( $r - int( $r ) > 0 ) {
	#     $r = int( $r ) + 1;
	# }

	push @result, $r;

	## Debugging statements
	# print "\nARRAY for $s / $t\n";
	# foreach my $arr ( @d ) {
	#     print join( " ", @$arr ) . "\n"
	# }
    }
    if (wantarray) {return @result} else {return $result[0]}
}
  

sub am_lc {
    my $char = shift;
    # Is it in the uppercase Armenian range?
    if( $char =~ /[\x{531}-\x{556}]/ ) {
	my $codepoint = unpack( "U", $char );
	$codepoint += 48;
	$char = pack( "U", $codepoint );
    }
    return $char;
}

1;
