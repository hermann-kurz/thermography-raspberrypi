#!/usr/bin/perl
{
package MyWebServer;
use HiPi::BCM2835;
use HiPi::BCM2835::I2C;
use HiPi::Utils;
my $last_raw=0;
my $raw=0;
# max difference to $last_raw until value is read again
my $max_diff=50;
my $diff=0;

# Hardware
my $register = 7;
HiPi::BCM2835->bcm2835_init();
my $dev = HiPi::BCM2835::I2C->new( address => 0x5a );

use HTTP::Server::Simple::CGI;
use base qw(HTTP::Server::Simple::CGI);

my %dispatch = (
    '/mlx' => \&resp_mlx,
);

sub handle_request {
    my $self = shift;
    my $cgi  = shift;
  
    my $path = $cgi->path_info();
    my $handler = $dispatch{$path};

    if (ref($handler) eq "CODE") {
        print "HTTP/1.0 200 OK\r\n";
        $handler->($cgi);
        
    } else {
        print "HTTP/1.0 404 Not found\r\n";
        print $cgi->header,
              $cgi->start_html('Not found'),
              $cgi->h1('Not found'),
              $cgi->end_html;
    }
}

sub resp_mlx {
    my $cgi  = shift;   # CGI.pm object
    $raw = 65535;
    return if !ref $cgi;

    my (@reg_val) = (255, 255);
# reading the sensor seems unreliable
# so read the sensor until the difference to the previous value
# is small enough ($max_diff is normally 1C)
    do {
# eval to avoid error propagting to output
# if an error occurs, set result to big integer to force reevaluation
         eval {
             @reg_val = $dev->i2c_read_register_rs($register, 0x02);
         };
# an error occured, set reg_val to an invaid value
         if ($@) {
             @reg_val = (255, 255);
         }
         $raw = @reg_val[1] * 256 + @reg_val[0];
         $diff = abs($raw - $last_raw);
         $last_raw = $raw;
    } while(($diff > $max_diff) or ($raw > 32000));

    my ($temp_c) = ($raw / 50) - 273.15 ;
    
    print $cgi->header;
    print "$temp_c";
    }

} 

# start the server on port 8080
my $pid = MyWebServer->new(8080)->background();
print "Use 'kill $pid' to stop server.\n";

