#include <Servo.h>      
#include <stdint.h>                                                        
Servo myservo;      

#define STATUS_CLOSED 0
#define STATUS_OPEN 1
#define ANGLE_CLOSED 30
#define ANGLE_OPEN 0

String status_str[2]={"closed","open"};
int current_status = STATUS_OPEN;
uint32_t millis_limit = 0;
                                                                                
void setup(){            
  Serial.begin(115200,SERIAL_8N1);  
  //Serial.begin(9600);                                                     
  myservo.attach(9);                                                            
  myservo.write(ANGLE_OPEN);// move servos to center position -> 90°
  delay(500);
  myservo.write(ANGLE_CLOSED);
  delay(500);
  myservo.write(ANGLE_OPEN);
  delay(500);
  feedback();
}

void echo(String msg) {
  Serial.println("echo: " + msg);
}
void feedback() {
  uint32_t remain=0;
  if (millis_limit > 0) {
    remain = millis_limit - millis();
  }
  Serial.println("status: " + status_str[current_status] + " " + remain);
}               

void open() {
  millis_limit=0;
  myservo.write(ANGLE_OPEN);
  current_status = STATUS_OPEN;
  delay(500);
}

void close(uint32_t l){
  millis_limit = l;
  myservo.write(ANGLE_CLOSED);
  current_status = STATUS_CLOSED;
  delay(500);
}

void loop(){        
  //Serial.println("loop"); 
  if (current_status==STATUS_CLOSED && millis_limit > 0) {
    uint32_t current_millis = millis();
    if (current_millis > millis_limit) {
      open();
    }
  }
  if (Serial.available()) {
    String msg = Serial.readString();
    echo(msg);
    if (msg.startsWith("close")) {
      int space = msg.indexOf(" ");
      if (space!=-1) {
        unsigned int secs = msg.substring(space+1).toInt();
        if (secs>0) {
          uint32_t secs_millis = secs*1000;
          uint32_t now = millis();
          millis_limit = now + secs_millis;
          echo("Closing box for " + String(secs) + " seconds " + now + " " + secs_millis + " " + millis_limit);
          close(millis_limit);
        } else {
          close(0);
        }
      } else {
        close(0);
      }
    } else if (msg.startsWith("open")) {
      open();
    }
    feedback();
  }
}
