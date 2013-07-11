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
PWM.set_loglevel(PWM.LOG_LEVEL_ERRORS)
##PWM.setup(pulse_incr_us=10, delay_hw=1)
PWM.setup(pulse_incr_us=10, delay_hw=0)

# servo pins
servo_x=25
servo_y=24
mlx_url="http://localhost:8080/mlx"


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
  pause=.1
  pause_line=1

  if resolution == 'small':
    start_pos=1200
    end_pos=1800
    step_count=10
    pause=.15
    pause_line=.3
  
  if resolution == 'big':
    start_pos=1200
    end_pos=1800
    step_count=48
    pause=.1
    pause_line=.3
  
#
  step_size=round(((end_pos-start_pos)/(step_count-1)/10))*10
  x=0
  y=0


  data=np.zeros((step_count, step_count))

  servo = PWM.Servo()
##  servo.__init__(0,6000,10)
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
  data = np.flipud(data)
##data = np.fliplr(data)
# Generate heatmap from data array
  cmap = cm.get_cmap('jet')
  plt.clf()
  plt.imshow(data, interpolation="nearest", cmap=cmap)
  plt.axis('off')
# add temp colorbar
  cb = plt.colorbar()
  cb.set_label('Temp (in C)')
  plt.savefig('/root/thermo/scripts/images/heatmap.png')

# save again with datecoded filename 
  date_string = datetime.now().strftime("%Y-%m-%d--%H-%M")
  plt.savefig('/root/thermo/scripts/images/heatmap' + date_string + '.png')

  redirect("/html/index.html")

run(host='0.0.0.0', port=80)
#run(host='192.168.1.1', port=80)
