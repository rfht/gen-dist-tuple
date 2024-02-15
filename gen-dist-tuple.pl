#!/usr/bin/env perl

# Copyright (c) 2024 Thomas Frohwein <thfr@openbsd.org>
#
# Permission to use, copy, modify, and distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

use strict;
use warnings;
use v5.36;
use Readonly;

Readonly my $DIST_TUPLE_LENGTH	=> 5;
Readonly my @VALID_TEMPLATES	=> ( 'github' );

my @dist_tuple;	# the variable to fill for the final output

sub usage() {
	say "usage:\tgen-dist-tuple.pl template account project tagname";
	say "\tgen-dist-tuple.pl template account project commithash";
	exit 1;
}

sub is_hash( $s ) {
	return $s =~ m/^[0-9a-f]{10,40}$/;
}

sub get_submodule_list( $template, $account, $project, $id ) {
	my @submodules;

	# github template
	my $gitmodules_remote = "https://raw.githubusercontent.com/$account/$project/$id/.gitmodules";
	my @raw_gitmodules = split( "\n", `ftp -Vo - $gitmodules_remote` );
	if ( grep( /ftp: Error/, @raw_gitmodules) ) {
		die "Error retrieving submodule list from $gitmodules_remote";
	}
	@submodules = map { m/^\s*path\s*=\s*(.*)\s*$/ ? ( $1 ) : () } @raw_gitmodules;

	return @submodules;
}

sub get_submodule_info( $template, $account, $project, $id, $submodule ) {
	my @submodule_tuple = ( $template );

	# github template

	my $submod_remote;
	if ( is_hash( $id ) ) {
		$submod_remote = "https://api.github.com/repos/$account/$project/contents/$submodule?sha=$id";
	}
	else {
		$submod_remote = "https://api.github.com/repos/$account/$project/contents/$submodule?ref=$id";
	}

	my $raw_submod_json = `ftp -Vo - $submod_remote`;
	if ( grep( /ftp: Error/, $raw_submod_json) ) {
		die "Error retrieving submodule content from $submod_remote";
	}

	( my $git_url ) = ( $raw_submod_json =~ /\"git_url\":\"([^\"]*)/ );
	# example git_url: https://api.github.com/repos/spring/Python/git/trees/b69a4ea06bb780d68b5934d5d6ce1b93a684514b
	# Example json content of interest:
	# "sha":"0ddd86eaa8871dc0833c69f931f55cd856c5009d"
	# "submodule_git_url": "https://github.com/spring/SpringMapConvNG.git
	push @submodule_tuple, ( $git_url =~ m{api\.github\.com/repos/([^/]*)/(.*)/git/trees/([a-z0-9]*)} );
	if ( scalar( @submodule_tuple ) != 4 ) {
		die "incomplete tuple from $git_url";
	}
	push @submodule_tuple, $submodule;

	return @submodule_tuple;
}

### main ###

usage() if $#ARGV != 3;
my ($template, $account, $project, $id) = @ARGV;
push @dist_tuple, ( $template, $account, $project, $id, '.' );

unless ( grep( /^\Q$template\E$/, @VALID_TEMPLATES ) ) {
	say "Not a valid template: $template";
	say 'Valid templates: ' . join( ' ', @VALID_TEMPLATES );
	exit 1;
}

my @submodules = get_submodule_list( $template, $account, $project, $id );

foreach my $s ( @submodules ) {
	push @dist_tuple, get_submodule_info ( $template, $account, $project, $id, $s );
}

while ( @dist_tuple ) {
	print "DIST_TUPLE +=";
	for ( my $i = 0; $i < $DIST_TUPLE_LENGTH; $i++ ) {
		print ' ';
		print( shift( @dist_tuple ) );
	}
	say '';
}
