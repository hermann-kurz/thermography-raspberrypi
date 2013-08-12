from bottle import route, run, template, static_file, redirect
import time
import urllib2
import numpy as np
import matplotlib as mpl

# we are running headless, use "Agg" as backend for matplotlib
mpl.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.cm as cm
from datetime import datetime
from RPIO import PWM

# setup PWM hardware
pulse_incr=1
PWM.set_loglevel(PWM.LOG_LEVEL_ERRORS)

# servo pins
servo_x=25
servo_y=24

# sensor URL
# use degrees celsius
mlx_url="http://localhost:8080/c"
# if you want to use degrees fahrenheit uncomment next line
#mlx_url="http://localhost:8080/f"


@route('/')
def send_root():
  redirect("/html/index.html")

@route('/images/<filename:path>')
def send_image(filename):
  return static_file(filename, root='/root/thermo/scripts/images', mimetype='image/png')

@route('/html/<filename:path>')
def send_static(filename):
  return static_file(filename, root='/root/thermo/scripts/html')

# default mode redirection
@route('/do')
def redirect_it():
  redirect("/do/default")

# different resolutions, "default", "small", "big"
# Load paramaters for each resolution
@route('/do/<resolution>')
def do_it(resolution):

# default parameters
# set start, end (this is hardware dependent) and number of steps
  start_pos=1200
  end_pos=1800
  step_count=32
  pause=.15
  pause_line=.5

  if resolution == 'small':
    start_pos=1200
    end_pos=1800
    step_count=10
    pause=.15
    pause_line=.5
  
  if resolution == 'big':
    start_pos=1200
    end_pos=1800
    step_count=48
    pause=.15
    pause_line=.5
  
# compute step size, round to pulse_incr
  step_size=round(((end_pos-start_pos)/(step_count-1)/pulse_incr))*pulse_incr
  x=0
  y=0

# init data array for temp samples
  data=np.zeros((step_count, step_count))
# setup Hardware
  servo = PWM.Servo(dma_channel=0, 
                    subcycle_time_us=4000, 
                    pulse_incr_us=pulse_incr)

# move to start
  servo.set_servo(servo_x, start_pos)
  servo.set_servo(servo_y, start_pos)

# Sweep thru one frame
  for x in range(step_count):
    servo.set_servo(servo_x, start_pos + x * step_size)
    servo.set_servo(servo_y, start_pos)
    time.sleep(pause_line)
    for y in range(step_count):
      servo.set_servo(servo_y, start_pos + y * step_size)
      time.sleep(pause)
      response=urllib2.urlopen(mlx_url)
      temperature=response.read()
      data[x,y]=temperature

# flip array to get correct orientation
# depends on your hardware setup
#
##  data = np.flipud(data)
##  data = np.fliplr(data)
# Generate heatmap from data array
  cmap = cm.get_cmap('jet')
  plt.clf()
  plt.imshow(data, interpolation="nearest", cmap=cmap)
  plt.axis('off')
# add temp colorbar
  cb = plt.colorbar()
  date_disp = datetime.now().strftime("%Y-%m-%d  %H:%M")
  cb.set_label('Temp (in C)  ' + date_disp)
  plt.savefig('/root/thermo/scripts/images/heatmap.png')

# save again with datecoded filename 
  date_string = datetime.now().strftime("%Y-%m-%d--%H-%M")
  plt.savefig('/root/thermo/scripts/images/heatmap' + date_string + '.png')

  redirect("/html/index.html")

# start web server for all interfaces on port 80
run(host='0.0.0.0', port=80)

