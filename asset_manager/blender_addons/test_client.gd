@tool
extends Node3D

var last_update: int	

@export var server_started: bool:
	set(val):
		if not is_node_ready(): return
		if val:
			TCPIO.start_server()
			server_started = true
			last_update = Time.get_ticks_msec()
		else:
			server_started = false
			TCPIO.stop_server()
			
@export var check_connections: bool:
	set(val):
		TCPIO.update_client_list()
		last_update = Time.get_ticks_msec() + 1000
				
@export var send: bool:
	set(val):
		last_update = Time.get_ticks_msec() +1000 if TCPIO.update_client_list() else Time.get_ticks_msec()			
		TCPIO.send_update()		
		
@export var receive: bool:
	set(val):
		last_update = Time.get_ticks_msec() +1000 if TCPIO.update_client_list() else Time.get_ticks_msec()			
		TCPIO.receive_messages()
		
@export var realtime := false
	
@export var TIMER_INTERVAL: int = 900 #msecs
			
# REALTIME ONLY
func _process(_delta):		
	if not server_started or not realtime: return
	TCPIO.update_client_list()		
	if Time.get_ticks_msec()-last_update > TIMER_INTERVAL:
		last_update = Time.get_ticks_msec()
		TCPIO.receive_messages()		
		TCPIO.send_update()
