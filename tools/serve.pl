#!/usr/bin/perl
# Mini-webserver om de app lokaal te testen (geen Node/Python nodig).
#   perl tools/serve.pl [poort]    -> http://localhost:5060
use strict;
use warnings;
use IO::Socket::IP;
use FindBin;
use File::Basename qw(dirname);

my $ROOT = dirname($FindBin::Bin);
my $PORT = shift @ARGV || 5060;
my %TYPES = (html => 'text/html; charset=utf-8', js => 'text/javascript', json => 'application/json',
             png => 'image/png', css => 'text/css', svg => 'image/svg+xml', ico => 'image/x-icon');

my $srv = IO::Socket::IP->new(LocalHost => '::', LocalService => $PORT, V6Only => 0, Listen => 10, ReuseAddr => 1)
  or die "Kan poort $PORT niet openen: $!\n";
$| = 1;
print "Server draait op http://localhost:$PORT\n";

while (my $c = $srv->accept) {
  # Luistert op IPv4 en IPv6, maar alleen verzoeken van deze Mac zelf worden beantwoord.
  my $peer = $c->peerhost // '';
  unless ($peer eq '::1' || $peer =~ /^(::ffff:)?127\./) { print "geweigerd: $peer\n"; close $c; next }
  my $req = <$c> // '';
  while (my $l = <$c>) { last if $l =~ /^\r?\n$/ }
  my ($path) = $req =~ m{^GET\s+(\S+)} or do { close $c; next };
  $path =~ s/\?.*//;
  $path = '/index.html' if $path eq '/';
  $path =~ s/%([0-9A-Fa-f]{2})/chr hex $1/ge;
  my $file = "$ROOT$path";
  if ($path =~ /\.\./ || $path =~ m{^/(tools|CLAUDE\.md|\.)} || !-f $file) {
    print $c "HTTP/1.0 404 Not Found\r\nContent-Type: text/plain\r\n\r\nNot found";
    print "404 $path\n";
  } else {
    my ($ext) = $file =~ /\.(\w+)$/;
    open(my $fh, '<:raw', $file);
    local $/;
    my $body = <$fh>;
    print $c "HTTP/1.0 200 OK\r\nContent-Type: " . ($TYPES{lc($ext // '')} // 'application/octet-stream')
      . "\r\nContent-Length: " . length($body) . "\r\nCache-Control: no-store\r\n\r\n" . $body;
    print "200 $path\n";
  }
  close $c;
}
