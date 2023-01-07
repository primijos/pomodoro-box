#include <Servo.h>                                                              
Servo myservo;      

#define STATUS_CLOSED 0
#define STATUS_OPEN 1
#define ANGLE_CLOSED 30
#define ANGLE_OPEN 0

String status_str[2]={"closed","open"};
int current_status = STATUS_OPEN;
                                                                                
void setup(){            
  Serial.begin(9600);                                                       
  myservo.attach(9);                                                            
  myservo.write(ANGLE_OPEN);// move servos to center position -> 90°
  feedback();
}   
void feedback() {
  Serial.println("status: " + status_str[current_status]);
}                                                                            
void loop(){        
  //Serial.println("loop"); 
  if (Serial.available()) {
    String msg = Serial.readString();
    if (msg.startsWith("close")) {
      myservo.write(ANGLE_CLOSED);
      current_status = STATUS_CLOSED;
    } else if (msg.startsWith("open")) {
      myservo.write(ANGLE_OPEN);
      current_status = STATUS_OPEN;
    }
    feedback();
  }                                                           
  /*
  myservo.write(90);// move servos to center position -> 90°                    
  delay(500);                                                                   
  myservo.write(30);// move servos to center position -> 60°                    
  delay(500);                                                                   
  myservo.write(90);// move servos to center position -> 90°                    
  delay(500);                                                                   
  myservo.write(150);// move servos to center position -> 120°                  
  delay(500);                                                                  
  */ 
}
