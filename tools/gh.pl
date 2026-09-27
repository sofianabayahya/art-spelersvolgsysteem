#!/usr/bin/perl
# Vervanger voor git zolang de Command Line Developer Tools niet geinstalleerd zijn.
# Praat met de GitHub-API via curl, met de token uit de macOS-sleutelhanger (github-art-token).
#
#   perl tools/gh.pl status                 welke lokale bestanden wijken af van GitHub (main)
#   perl tools/gh.pl pull                   haal alle bestanden van GitHub op (overschrijft lokaal)
#   perl tools/gh.pl push "bericht" a b ... maak 1 commit op main met de genoemde bestanden
#
# push weigert als GitHub intussen buiten ons om is gewijzigd (dan eerst status/pull).
use strict;
use warnings;
use JSON::PP;
use MIME::Base64;
use Digest::SHA qw(sha1_hex);
use File::Temp qw(tempfile);
use File::Path qw(make_path);
use File::Basename qw(dirname);
use FindBin;

my $OWNER  = 'sofianabayahya';
my $REPO   = 'art-spelersvolgsysteem';
my $BRANCH = 'main';
my $API    = "https://api.github.com/repos/$OWNER/$REPO";
my $ROOT   = dirname($FindBin::Bin);
my $SYNC   = "$ROOT/.last-sync";
my %LOCAL_ONLY = map { $_ => 1 } ('.last-sync', '.DS_Store');

my $json = JSON::PP->new->utf8->canonical;
my $TOKEN;

sub token {
  my $t = `security find-generic-password -s github-art-token -w 2>/dev/null`;
  chomp $t;
  die "Geen token gevonden in de sleutelhanger (github-art-token).\n" unless $t;
  return $t;
}

sub api {
  my ($method, $path, $body) = @_;
  $TOKEN //= token();
  my ($cfh, $cfg) = tempfile(UNLINK => 1);
  chmod 0600, $cfg;
  print $cfh "header = \"Authorization: Bearer $TOKEN\"\n",
             "header = \"Accept: application/vnd.github+json\"\n",
             "header = \"X-GitHub-Api-Version: 2022-11-28\"\n";
  close $cfh;
  my @cmd = ('curl', '-sS', '-X', $method, '-K', $cfg, '-w', "\n%{http_code}");
  if (defined $body) {
    my ($bfh, $bfile) = tempfile(UNLINK => 1);
    binmode $bfh;
    print $bfh $json->encode($body);
    close $bfh;
    push @cmd, '-H', 'Content-Type: application/json', '--data-binary', "\@$bfile";
  }
  push @cmd, "$API$path";
  open(my $out, '-|', @cmd) or die "curl starten mislukt: $!\n";
  local $/;
  my $res = <$out>;
  close $out;
  unlink $cfg;
  $res =~ s/\n(\d{3})\z// or die "Onverwacht antwoord van GitHub.\n";
  my $code = $1;
  die "GitHub $method $path gaf $code: $res\n" if $code >= 300;
  return length $res ? $json->decode($res) : {};
}

sub head_sha { api('GET', "/git/ref/heads/$BRANCH")->{object}{sha} }

sub remote_files {
  my ($commit) = @_;
  my $tree_sha = api('GET', "/git/commits/$commit")->{tree}{sha};
  my $tree = api('GET', "/git/trees/$tree_sha?recursive=1");
  return { map { $_->{path} => $_->{sha} } grep { $_->{type} eq 'blob' } @{ $tree->{tree} } };
}

sub read_file {
  my ($p) = @_;
  open(my $fh, '<:raw', "$ROOT/$p") or die "Kan $p niet lezen: $!\n";
  local $/;
  return scalar <$fh>;
}

sub blob_sha { my ($c) = @_; sha1_hex('blob ' . length($c) . "\0" . $c) }

sub local_files {
  my @out;
  my @dirs = ('');
  while (defined(my $d = shift @dirs)) {
    opendir(my $dh, $d eq '' ? $ROOT : "$ROOT/$d") or next;
    for my $e (sort readdir $dh) {
      next if $e eq '.' || $e eq '..' || $LOCAL_ONLY{$e};
      my $rel = $d eq '' ? $e : "$d/$e";
      if (-d "$ROOT/$rel") { push @dirs, $rel } else { push @out, $rel }
    }
  }
  return @out;
}

sub last_sync {
  open(my $fh, '<', $SYNC) or return '';
  my $s = <$fh> // '';
  chomp $s;
  return $s;
}

sub write_sync {
  open(my $fh, '>', $SYNC) or die "Kan .last-sync niet schrijven: $!\n";
  print $fh "$_[0]\n";
}

my $cmd = shift @ARGV // '';

if ($cmd eq 'status') {
  my $head = head_sha();
  my $remote = remote_files($head);
  my $synced = last_sync();
  print "GitHub main: ", substr($head, 0, 7), "\n";
  print "Laatst gesynchroniseerd: ", ($synced ? substr($synced, 0, 7) : '(nooit)'), "\n";
  print "LET OP: GitHub is gewijzigd sinds de laatste sync.\n" if $synced && $synced ne $head;
  my %seen;
  for my $p (local_files()) {
    $seen{$p} = 1;
    if (!exists $remote->{$p}) { print "  nieuw      $p\n" }
    elsif (blob_sha(read_file($p)) ne $remote->{$p}) { print "  gewijzigd  $p\n" }
  }
  print "  alleen op GitHub  $_\n" for grep { !$seen{$_} } sort keys %$remote;
}
elsif ($cmd eq 'pull') {
  my $head = head_sha();
  my $remote = remote_files($head);
  for my $p (sort keys %$remote) {
    my $blob = api('GET', "/git/blobs/$remote->{$p}");
    my $dir = dirname("$ROOT/$p");
    make_path($dir) unless -d $dir;
    open(my $fh, '>:raw', "$ROOT/$p") or die "Kan $p niet schrijven: $!\n";
    print $fh decode_base64($blob->{content});
    close $fh;
    print "  opgehaald  $p\n";
  }
  write_sync($head);
  print "Gesynchroniseerd met ", substr($head, 0, 7), "\n";
}
elsif ($cmd eq 'push') {
  my $msg = shift @ARGV;
  die "Gebruik: perl tools/gh.pl push \"bericht\" bestand1 [bestand2 ...]\n" unless $msg && @ARGV;
  my $head = head_sha();
  my $synced = last_sync();
  die "GitHub staat op " . substr($head, 0, 7) . ", laatste sync was " . ($synced ? substr($synced, 0, 7) : '(nooit)')
    . ". Er is buiten ons om iets gewijzigd; eerst 'status' bekijken.\n" if $synced ne $head;
  my @tree;
  for my $p (@ARGV) {
    my $blob = api('POST', '/git/blobs', { content => encode_base64(read_file($p), ''), encoding => 'base64' });
    push @tree, { path => $p, mode => '100644', type => 'blob', sha => $blob->{sha} };
  }
  my $base_tree = api('GET', "/git/commits/$head")->{tree}{sha};
  my $tree = api('POST', '/git/trees', { base_tree => $base_tree, tree => \@tree });
  my $commit = api('POST', '/git/commits', { message => $msg, tree => $tree->{sha}, parents => [$head] });
  api('PATCH', "/git/refs/heads/$BRANCH", { sha => $commit->{sha} });
  write_sync($commit->{sha});
  print "Gepusht: ", substr($commit->{sha}, 0, 7), " op $BRANCH\n";
}
elsif ($cmd eq 'push-test') {
  # Zet main + de genoemde bestanden op branch "test" (overschrijft die branch). Vercel maakt daar
  # een Preview-deployment van; www.artsvs.nl blijft ongemoeid.
  my $msg = shift @ARGV;
  die "Gebruik: perl tools/gh.pl push-test \"bericht\" bestand1 [bestand2 ...]\n" unless $msg && @ARGV;
  my $head = head_sha();
  my @tree;
  for my $p (@ARGV) {
    my $blob = api('POST', '/git/blobs', { content => encode_base64(read_file($p), ''), encoding => 'base64' });
    push @tree, { path => $p, mode => '100644', type => 'blob', sha => $blob->{sha} };
  }
  my $base_tree = api('GET', "/git/commits/$head")->{tree}{sha};
  my $tree = api('POST', '/git/trees', { base_tree => $base_tree, tree => \@tree });
  my $commit = api('POST', '/git/commits', { message => $msg, tree => $tree->{sha}, parents => [$head] });
  my $exists = eval { api('GET', '/git/ref/heads/test'); 1 };
  if ($exists) { api('PATCH', '/git/refs/heads/test', { sha => $commit->{sha}, force => JSON::PP::true }) }
  else { api('POST', '/git/refs', { ref => 'refs/heads/test', sha => $commit->{sha} }) }
  print "Op branch test gezet: ", substr($commit->{sha}, 0, 7), "\n";
}
else {
  print "Gebruik: perl tools/gh.pl status | pull | push \"bericht\" bestand... | push-test \"bericht\" bestand...\n";
  exit 1;
}
