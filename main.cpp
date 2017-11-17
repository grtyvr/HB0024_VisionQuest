/*
 *  Servo Control sketch.
 *  courtesy of zagGrad https://www.sparkfun.com/users/26876
 *  July 15, 2011
 *  https://www.sparkfun.com/tutorials/304
 *
 */

#include <Arduino.h>
#include <Servo.h>  //Used to control the Pan/Tilt Servos

//These are variables that hold the servo IDs.
char tiltChannel=0, panChannel=1;

//These are the objects for each servo.
Servo servoTilt, servoPan;

//This is a character that will hold data from the Serial port.
char serialChar=0;

void setup(){
servoTilt.attach(2);  //The Tilt servo is attached to pin 2.
servoPan.attach(3);   //The Pan servo is attached to pin 3.
servoTilt.write(90);  //Initially put the servos both
servoPan.write(90);      //at 90 degress.

Serial.begin(9600);  //Set up a serial connection for 57600 bps.
}

void loop(){
while(Serial.available() <=0);  //Wait for a character on the serial port.
serialChar = Serial.read();     //Copy the character from the serial port to the variable
if(serialChar == tiltChannel){  //Check to see if the character is the servo ID for the tilt servo
  while(Serial.available() <=0);  //Wait for the second command byte from the serial port.
  servoTilt.write(Serial.read());  //Set the tilt servo position to the value of the second command byte received on the serial port
}
else if(serialChar == panChannel){ //Check to see if the initial serial character was the servo ID for the pan servo.
  while(Serial.available() <= 0);  //Wait for the second command byte from the serial port.
  servoPan.write(Serial.read());   //Set the pan servo position to the value of the second command byte received from the serial port.
}
//If the character is not the pan or tilt servo ID, it is ignored.
}
