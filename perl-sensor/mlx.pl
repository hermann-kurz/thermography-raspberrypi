#!/usr/bin/perl
{
package MyWebServer;
use HiPi::BCM2835;
use HiPi::BCM2835::I2C;
use HiPi::Utils;

my $last_raw=0;
# max difference to $last_raw until value is read again
my $max_diff=50;

# Hardware
my $register = 7;
HiPi::BCM2835->bcm2835_init();
my $dev = HiPi::BCM2835::I2C->new( address => 0x5a );

use HTTP::Server::Simple::CGI;
use base qw(HTTP::Server::Simple::CGI);

# return temperature as degree celsius, degree fahrenheit, raw value
# or as json (in all variants)
# at URLs /c, /f, /raw, /json
my %dispatch = (
    '/c' => \&resp_c,
    '/f' => \&resp_f,
    '/raw' => \&resp_raw,
    '/json' => \&resp_json
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
# degree celsius
sub resp_c {
    my $cgi  = shift;   # CGI.pm object
    my $raw = &raw_mlx();
    my ($temp_c) = ($raw / 50) - 273.15 ;
    
    print $cgi->header;
    print "$temp_c";
    }

# degree fahrenheit
sub resp_f {
    my $cgi  = shift;   # CGI.pm object
    my $raw = &raw_mlx();
    my ($temp_c) = ($raw / 50) - 273.15 ;
    my $temp_f = $temp_c * 1.8 +32; 

    print $cgi->header;
    print "$temp_f";
    }

# raw sensor value
sub resp_raw {
    my $cgi  = shift;   # CGI.pm object
    my $raw = &raw_mlx();

    print $cgi->header;
    print "$raw";
    }

# celsius, fahrenheit and raw value as json
sub resp_json {
    my $cgi  = shift;   # CGI.pm object
    my $raw = &raw_mlx();
    my $temp_c = ($raw / 50) - 273.15 ;
    my $temp_f = $temp_c * 1.8 +32; 

    print $cgi->header(-Content_type => 'application/json');
    print "{ \"celsius\": $temp_c, \"fahrenheit\": $temp_f, \"raw\": $raw }";
    }

sub raw_mlx {
    my $raw = 65535;
    my $diff=0;
    my (@reg_val) = (255, 255);

# reading the sensor seems unreliable
# so read the sensor until the difference to the previous value
# is small enough ($max_diff is normally 50 == 1 degree celsius)
    do {
# eval to avoid error propagating to output
# if an error occurs, set result to big integer to force reevaluation
         eval {
             @reg_val = $dev->i2c_read_register_rs($register, 0x02);
         };
# an error occured, set reg_val to an invalid value
         if ($@) {
             @reg_val = (255, 255);
         }
         $raw = @reg_val[1] * 256 + @reg_val[0];
         $diff = abs($raw - $last_raw);
         $last_raw = $raw;
    } while(($diff > $max_diff) or ($raw > 32000));

    return $raw;
    }

} 

# start the server on port 8080
my $pid = MyWebServer->new(8080)->background();
print "Use 'kill $pid' to stop server.\n";

