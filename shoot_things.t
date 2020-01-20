%%%%%%%%%%%%%%%%%% VARIABLE DECLARATION %%%%%%%%%%%%%%%%%%%%%%%%%%
var input, ult_status : string (1) := ""        % (in order) variable to store user input, variable that indicates the phase of the ultimate ability
var upgrade_points : int := 0                   % number of upgrade points available to the player
var upgrade_menu_position : int := 300          % controls the visibility of the upgrade menu
var game_status : string := "start"             % controls which screen is showing
var ammo : int := 50                            % number of bullets the player can fire
var score : int := 0                            % score that increases with time
var upgrades : array 1 .. 4 of int := init (0, 0, 0, 0)     % 1. bullet power, 2. reload speed, 3. firing rate, 4. ultimate ability regeneration rate
var ult_charge : int := 0                       % percentage of ultimate ability charged
var ult_ind_radius, ult_attack_radius, ult_finish_radius : int := 0     % (in order) controls ultimate ability indicator circle, controls ultimate ability visual effects, ~
var text_blink_ind : int := 1                   % controls blinking of percentage indicator when at 100%
var tutorial_proceed : boolean := false         % controls pace of tutorial
var tutorial_text_color : int := 26             % used to fade the text during the tutorial
var tutorial_phase : string := "LMB"            % used to progress tutorial
var end_text_color_timer : int := 16            % used to fade the text on the loss screen
var mouse_x, mouse_y, shooting : int := 0           % variables to store mouse pointer information
var secondary_fire_ready : boolean := true          % controls rate of right-click fire
var font1 : int := Font.New ("Agency FB:18:bold")   % primary font
var font2 : int := Font.New ("Agency FB:14")        % smaller font used for upgrade points counter
var font3 : int := Font.New ("Agency FB:54:bold")   % title font
var font4 : int := Font.New ("Agency FB:36:bold")   % play button font
var fps : int := 240                            % frames per second at which the game runs; also the rate at which the in-game values are updated, so a higher fps means more accurate physics
var g : real := -0.1                            % gravity constant
var boss_fight, end_boss_fight : boolean := false               % boss fight status indicators
var bullets : array 1 .. 50 of array 1 .. 5 of real             % array to store all information about bullets
% (x coordinate, y coordinate, x velocity, y velocity, radius)
for i : 1 .. 50                                 % set default values
    bullets (i) (1) := -25
    bullets (i) (2) := -25
    bullets (i) (3) := 0
    bullets (i) (4) := 0
    bullets (i) (5) := 8
end for
var asteroids : array 1 .. 6 of array 1 .. 7 of real    % array to store all information about asteroids
% (x coordinate, y coordinate, x velocity, y velocity, radius, launched, hit)
for i : 1 .. upper (asteroids)                  % set default values
    asteroids (i) (1) := -1000
    asteroids (i) (2) := -1000
    asteroids (i) (3) := 0
    asteroids (i) (4) := 0
    asteroids (i) (5) := 1
    asteroids (i) (6) := 0
    asteroids (i) (7) := 0
end for

%%%%%%%%%%%%%%%%%%%%%%% FUNCTIONS AND PROCEDURES %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function moving (arr : array 1 .. * of real) : boolean      % function that accepts a single bullet or asteroid's array and returns whether or not it is moving
    if arr (3) = 0 and arr (4) = 0 then
	result false
    end if
    result true
end moving

function unit_multiple (a, b : real) : real         % accepts components of a 2-D vector and returns the coefficient of the scalar multiple of the original vector with magnitude 1
    result 1 / sqrt (a ** 2 + b ** 2)
end unit_multiple

procedure draw_player_elements                  % draws the player's dome thing
    Draw.FillOval (500, -500, 1500, 600, 20)
    Draw.FillArc (500, 140, 200, 100, 234, 306, 30)
    Draw.FillArc (500, 60, 120, 100, 0, 180, 30)
    Draw.FillOval (500, 143, 25, 10, 26)
    Draw.FillOval (500, 140, 25, 8, 7)
    Draw.FillBox (405, 65, 595, 95, 24)
    Draw.FillBox (410, 70, round (410 + 3.6 * ammo), 90, 30)
end draw_player_elements

procedure draw_bullets                          % draws bullets inidividually based on their position and radius information
    for i : 1 .. upper (bullets)
	if bullets (i) (5) = 10 then
	    Draw.FillOval (round (bullets (i) (1)), round (bullets (i) (2)), round (bullets (i) (5)), round (bullets (i) (5)), 100)
	else
	    Draw.FillOval (round (bullets (i) (1)), round (bullets (i) (2)), round (bullets (i) (5)), round (bullets (i) (5)), 30)
	end if
	Draw.Oval (round (bullets (i) (1)), round (bullets (i) (2)), round (bullets (i) (5)), round (bullets (i) (5)), colorbg)
    end for
end draw_bullets

function in_array (num : int, arr : array 1 .. * of int) : boolean      % indicates whether an integer num appears in an integer array arr
    for i : 1 .. upper (arr)
	if num = arr (i) then
	    result true
	end if
    end for
    result false
end in_array

function index_of_largest_asteroid (arr : array 1 .. * of array 1 .. 7 of real) : int   % returns the index of the asteroid with the largest radius in the array
    var temp_largest_index : int := 1
    for i : 1 .. upper (arr)
	if arr (i) (5) > arr (temp_largest_index) (5) then
	    temp_largest_index := i
	end if
    end for
    result temp_largest_index
end index_of_largest_asteroid

function index_of_smallest_asteroid (arr : array 1 .. * of array 1 .. 7 of real) : int  % returns the index of the asteroid with the smallest radius in the array
    var temp_smallest_index : int := 1
    for i : 1 .. upper (arr)
	if arr (i) (5) < arr (temp_smallest_index) (5) then
	    temp_smallest_index := i
	end if
    end for
    result temp_smallest_index
end index_of_smallest_asteroid

function nth_largest_asteroid (arr : array 1 .. * of array 1 .. 7 of real, n : int) : int       % takes asteroid array and an integer n, and returns index of the nth largest asteroid in the array
    var asteroids_by_decreasing_size : array 1 .. upper (arr) of int                            % used to ensure the smaller asteroids are drawn after the larger ones, so they are not covered up
    asteroids_by_decreasing_size (1) := index_of_largest_asteroid (arr)
    for i : 2 .. upper (arr)
	asteroids_by_decreasing_size (i) := 0
    end for
    for i : 2 .. upper (arr)
	var temp_largest_index := index_of_smallest_asteroid (arr)
	for j : 1 .. upper (arr)
	    if not (in_array (j, asteroids_by_decreasing_size)) and arr (j) (5) >= arr (temp_largest_index) (5) then
		temp_largest_index := j
	    end if
	end for
	asteroids_by_decreasing_size (i) := temp_largest_index
    end for
    result asteroids_by_decreasing_size (n)
end nth_largest_asteroid

procedure draw_asteroids        % draws asteroids individually based on their position, radius, and starus information  (i.e. whether or not it is a boss)
    for i : 1 .. upper (asteroids)
	if asteroids (i) (6) = 2 then
	    Draw.FillOval (round (asteroids (nth_largest_asteroid (asteroids, i)) (1)), round (asteroids (nth_largest_asteroid (asteroids, i)) (2)),
		round (asteroids (nth_largest_asteroid (asteroids, i)) (5)), round (asteroids (nth_largest_asteroid (asteroids, i)) (5)), 184)
	else
	    Draw.FillOval (round (asteroids (nth_largest_asteroid (asteroids, i)) (1)), round (asteroids (nth_largest_asteroid (asteroids, i)) (2)),
		round (asteroids (nth_largest_asteroid (asteroids, i)) (5)), round (asteroids (nth_largest_asteroid (asteroids, i)) (5)), 111)
	end if
	Draw.Oval (round (asteroids (nth_largest_asteroid (asteroids, i)) (1)), round (asteroids (nth_largest_asteroid (asteroids, i)) (2)),
	    round (asteroids (nth_largest_asteroid (asteroids, i)) (5)), round (asteroids (nth_largest_asteroid (asteroids, i)) (5)), colorbg)
    end for
end draw_asteroids

procedure draw_UI               % draws primary user interface (in order: loss screen (if active), score counter, reticle, ult charge meter and counter, ult indicator,
    if game_status = "L" then   % upgrade menu and all its components, ultimate ability visual effects)
	Draw.FillBox (0, 0, maxx, maxy, black)                          % draw death screen elements
	Font.Draw ("You died.", 465, 500, font1, end_text_color_timer)
	if tutorial_phase = "end" then
	    Font.Draw ("You survived for " + intstr (score) + " seconds.", 390, 480, font1, end_text_color_timer)
	else
	    Font.Draw ("You didn't even survive the tutorial.", 370, 480, font1, end_text_color_timer)
	    Font.Draw ("Please consider uninstalling.", 395, 460, font1, end_text_color_timer)
	end if
	Draw.FillBox (430, 380, 570, 410, end_text_color_timer)
	if mouse_x < 570 and mouse_x > 430 and mouse_y < 410 and mouse_y > 380 then
	    Draw.FillBox (432, 382, 568, 408, 28)
	else
	    Draw.FillBox (432, 382, 568, 408, black)
	end if
	Font.Draw ("PLAY AGAIN", 453, 386, font1, end_text_color_timer)
	Draw.FillBox (430, 330, 570, 360, end_text_color_timer)
	if mouse_x < 570 and mouse_x > 430 and mouse_y < 360 and mouse_y > 330 then
	    Draw.FillBox (432, 332, 568, 358, 28)
	else
	    Draw.FillBox (432, 332, 568, 358, black)
	end if
	Font.Draw ("QUIT", 483, 336, font1, end_text_color_timer)

    elsif game_status = "game" then                                     % draw main user interface
	Font.Draw ("Score: " + intstr (score), 5, 975, font1, 30)

	Mouse.Where (mouse_x, mouse_y, shooting)
	Draw.Dot (mouse_x, mouse_y, 30)
	for i : 0 .. 1
	    Draw.Line (mouse_x, mouse_y - 5 + i * 10, mouse_x, mouse_y - 20 + i * 40, 30)
	    Draw.Line (mouse_x - 5 + i * 10, mouse_y, mouse_x - 20 + i * 40, mouse_y, 30)
	end for

	Draw.FillBox (670, 25, 910, 50, 30)
	Draw.FillBox (672, 27, 908, 48, 20)
	Draw.FillBox (674, 29, round (674 + 2.32 * ult_charge), 46, 26)
	Font.Draw (intstr (ult_charge) + " %", 925, 30, font1, 30)
	if ult_charge = 100 then
	    Draw.FillBox (670, 25, 910, 50, 100)
	    Draw.FillBox (672, 27, 908, 48, 20)
	    Draw.FillBox (674, 29, 906, 46, 100)
	    Font.Draw (intstr (ult_charge) + " %", 925, 30, font1, 48 + 28 * text_blink_ind)
	end if
	Draw.Oval (820, 36, ult_ind_radius, ult_ind_radius, white)

	% upgrades menu
	Draw.Box (745 + upgrade_menu_position, 710, 995 + upgrade_menu_position, 995, 30)
	Font.Draw ("UPGRADES", 832 + upgrade_menu_position, 975, font1, 30)
	if upgrade_points = 1 then
	    Font.Draw ("[1 pt.]", 925 + upgrade_menu_position, 975, font2, 30)
	else
	    Font.Draw ("[" + intstr (upgrade_points) + " pts.]", 925 + upgrade_menu_position, 975, font2, 30)
	end if
	Font.Draw ("Bullet Power [1]", 810 + upgrade_menu_position, 940, font1, 30)
	Font.Draw ("Reload Speed [2]", 805 + upgrade_menu_position, 880, font1, 30)
	Font.Draw ("Firing Rate [3]", 815 + upgrade_menu_position, 820, font1, 30)
	Font.Draw ("Ultimate Ability Generation [4]", 755 + upgrade_menu_position, 760, font1, 30)
	for i : 1 .. 4
	    Draw.Box (750 + upgrade_menu_position, (4 - i) * 60 + 730, 990 + upgrade_menu_position, (4 - i) * 60 + 750, 30)
	    for j : 1 .. upgrades (i)
		Draw.FillBox (754 + 59 * (j - 1) + upgrade_menu_position, (4 - i) * 60 + 732, 754 + 59 * (j) - 3 + upgrade_menu_position, (4 - i) * 60 + 748, 30)
	    end for
	end for

	for i : 1 .. upper (asteroids)
	    if asteroids (i) (6) not= 0 then
		Draw.Oval (round (asteroids (i) (1)), round (asteroids (i) (2)), ult_attack_radius, ult_attack_radius, 100)
	    end if
	end for

	for i : 1 .. 10
	    if ult_finish_radius mod 2 = 1 then
		Draw.FillArc (500, 140, ult_finish_radius, ult_finish_radius, (i - 1) * 36, round ((i - 1) * 36 + 18 * (1 + ult_finish_radius / 2000)), 100)
	    else
		Draw.FillArc (500, 140, ult_finish_radius, ult_finish_radius, (i - 1) * 36, round ((i - 1) * 36 + 18 * (1 + ult_finish_radius / 2000)), white)
	    end if
	end for
    elsif game_status = "start" then                        % draw start screen elements
	Font.Draw ("SHOOT THINGS", 330, 700, font3, 30)
	Draw.FillBox (400, 550, 600, 630, 30)
	Draw.FillBox (400, 450, 600, 530, 30)
	if mouse_x < 600 and mouse_x > 400 and mouse_y < 630 and mouse_y > 550 then
	    Draw.FillBox (405, 555, 595, 625, 28)
	    Draw.FillBox (405, 455, 595, 525, 26)
	elsif mouse_x < 600 and mouse_x > 400 and mouse_y < 530 and mouse_y > 450 then
	    Draw.FillBox (405, 555, 595, 625, 26)
	    Draw.FillBox (405, 455, 595, 525, 28)
	else
	    Draw.FillBox (405, 555, 595, 625, 26)
	    Draw.FillBox (405, 455, 595, 525, 26)
	end if
	Font.Draw ("PLAY", 465, 572, font4, 30)
	Font.Draw ("QUIT", 467, 472, font4, 30)
    end if
end draw_UI

procedure draw_tutorial                     % draws text that teaches player how to play
    if tutorial_phase = "LMB" then
	Font.Draw ("Press [Left Mouse Button].", 400, 600, font1, tutorial_text_color)
    elsif tutorial_phase = "RMB" then
	Font.Draw ("Press [Right Mouse Button].", 400, 600, font1, tutorial_text_color)
    elsif tutorial_phase = "redthings" then
	Font.Draw ("Red things are bad.", 430, 600, font1, tutorial_text_color)
	Font.Draw ("Don't let them hit you.", 420, 570, font1, tutorial_text_color)
    elsif tutorial_phase = "ammo" then
	Font.Draw ("Watch your ammo.", 700, 180, font1, tutorial_text_color)
	Draw.Line (700, 180, 600, 100, tutorial_text_color)
    elsif tutorial_phase = "upgrades" then
	Font.Draw ("Upgrades!", 460, 700, font1, tutorial_text_color)
	Font.Draw ("Select one to purchase with buttons [1], [2], [3], or [4].", 320, 670, font1, tutorial_text_color)
    elsif tutorial_phase = "ult1" then
	Font.Draw ("This is your ultimate ability charge meter.", 600, 150, font1, tutorial_text_color)
	Draw.Line (800, 150, 750, 50, tutorial_text_color)
    elsif tutorial_phase = "ult2" then
	Font.Draw ("When it reaches 100%,", 420, 500, font1, tutorial_text_color)
	Font.Draw ("press [Space] to make all your problems go away.", 320, 480, font1, tutorial_text_color)
    elsif tutorial_phase = "score" then
	Font.Draw ("This is your score.", 50, 900, font1, tutorial_text_color)
	Draw.Line (50, 920, 20, 980, tutorial_text_color)
    elsif tutorial_phase = "dontdie" then
	Font.Draw ("Don't die.", 460, 500, font1, tutorial_text_color)
    end if
end draw_tutorial

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% PROCESSES %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
process play_music                              % plays background music
    loop
	if ult_status = "" or ult_status = "E" then
	    Music.PlayFile ("miles_davis_freddie_freeloader.wav")
	end if
	exit when game_status = "L"
    end loop
end play_music

process draw_game               % process that combines all the draw commands with cls and View.Update for smooth animation
    loop
	cls
	exit when game_status = "restart"
	draw_tutorial
	draw_asteroids
	draw_player_elements
	draw_bullets
	draw_UI
	View.Update
    end loop
end draw_game

process tutorial                % process that detects the players progress and advances the tutorial accordingly
    loop
	loop
	    if shooting = 1 and mouse_x < 600 and mouse_x > 400 and mouse_y < 630 and mouse_y > 550 then
		exit
	    elsif shooting = 1 and mouse_x < 600 and mouse_x > 400 and mouse_y < 530 and mouse_y > 450 then
		quit
	    end if
	end loop
	game_status := "game"
	exit when game_status = "L"
	for i : 1 .. 4
	    delay (100)
	    tutorial_text_color += 1
	end for
	loop
	    exit when shooting = 1 or game_status = "L"
	end loop
	for i : 1 .. 4
	    delay (100)
	    tutorial_text_color -= 1
	end for
	delay (1000)
	exit when game_status = "L"
	tutorial_phase := "RMB"
	for i : 1 .. 4
	    delay (100)
	    tutorial_text_color += 1
	end for
	loop
	    exit when shooting = 100 or game_status = "L"
	end loop
	for i : 1 .. 4
	    delay (100)
	    tutorial_text_color -= 1
	end for
	delay (1000)
	exit when game_status = "L"
	tutorial_phase := "redthings"
	for i : 1 .. 4
	    delay (100)
	    tutorial_text_color += 1
	end for
	delay (5000)
	for i : 1 .. 4
	    delay (100)
	    tutorial_text_color -= 1
	end for
	delay (1000)
	exit when game_status = "L"
	tutorial_phase := "ammo"
	for i : 1 .. 4
	    delay (100)
	    tutorial_text_color += 1
	end for
	delay (3000)
	for i : 1 .. 4
	    delay (100)
	    tutorial_text_color -= 1
	end for
	delay (1000)
	exit when game_status = "L"
	tutorial_phase := "upgrades"
	upgrade_points += 1
	for i : 1 .. 4
	    delay (100)
	    tutorial_text_color += 1
	end for
	loop
	    exit when input = "1" or input = "2" or input = "3" or input = "4" or game_status = "L"
	end loop
	for i : 1 .. 4
	    delay (100)
	    tutorial_text_color -= 1
	end for
	delay (1000)
	exit when game_status = "L"
	tutorial_phase := "ult1"
	for i : 1 .. 4
	    delay (100)
	    tutorial_text_color += 1
	end for
	delay (3000)
	for i : 1 .. 4
	    delay (100)
	    tutorial_text_color -= 1
	end for
	delay (1000)
	exit when game_status = "L"
	tutorial_phase := "ult2"
	for i : 1 .. 4
	    delay (100)
	    tutorial_text_color += 1
	end for
	delay (5000)
	for i : 1 .. 4
	    delay (100)
	    tutorial_text_color -= 1
	end for
	delay (1000)
	exit when game_status = "L"
	tutorial_phase := "score"
	for i : 1 .. 4
	    delay (100)
	    tutorial_text_color += 1
	end for
	delay (3000)
	for i : 1 .. 4
	    delay (100)
	    tutorial_text_color -= 1
	end for
	delay (1000)
	exit when game_status = "L"
	tutorial_phase := "dontdie"
	for i : 1 .. 4
	    delay (100)
	    tutorial_text_color += 1
	end for
	delay (3000)
	for i : 1 .. 4
	    delay (100)
	    tutorial_text_color -= 1
	end for

	tutorial_phase := "end"
	loop
	    exit when game_status = "L"
	end loop
	exit
    end loop
end tutorial

process loss_screen_controls                % detects user input on loss screen and restarts or quits game accordingly
    loop
	if game_status = "L" then
	    loop
		Mouse.Where (mouse_x, mouse_y, shooting)
		if shooting = 1 and mouse_x < 570 and mouse_x > 430 and mouse_y < 410 and mouse_y > 380 then
		    delay (1000)
		    Draw.FillBox (0, 0, 1000, 1000, black)
		    game_status := "restart"
		    exit
		elsif shooting = 1 and mouse_x < 570 and mouse_x > 430 and mouse_y < 360 and mouse_y > 330 then
		    quit
		end if
	    end loop
	elsif game_status = "restart" then
	    exit
	end if
    end loop
end loss_screen_controls

process upgrades_menu           % increases upgrade points at a rate of 1 every 30 seconds
    loop
	if score mod 30 = 0 and (upgrades (1) < 4 or upgrades (2) < 4 or upgrades (3) < 4 or upgrades (4) < 4) and score not= 0 then
	    delay (1100)
	    upgrade_points += 1
	end if
	exit when game_status = "L"
    end loop
end upgrades_menu

process perform_upgrades        % accepts user input and expends one upgrade point to increase the corresponding upgrade stat
    loop
	if upgrade_points > 0 then
	    upgrade_menu_position := 0
	    if input = "1" and upgrades (1) < 4 then
		upgrades (1) += 1
		upgrade_points -= 1
	    elsif input = "2" and upgrades (2) < 4 then
		upgrades (2) += 1
		upgrade_points -= 1
	    elsif input = "3" and upgrades (3) < 4 then
		upgrades (3) += 1
		upgrade_points -= 1
	    elsif input = "4" and upgrades (4) < 4 then
		upgrades (4) += 1
		upgrade_points -= 1
	    end if
	    input := ""
	    delay (1000)
	    if upgrade_points = 0 then
		for i : 1 .. 100
		    delay (round (1000 / fps))
		    upgrade_menu_position := round (0.03 * i ** 2)
		end for
	    end if
	end if
	exit when game_status = "L"
    end loop
end perform_upgrades

process ult_indicator           % when ult charge reaches 99%, a visual cue is triggered
    loop
	if ult_charge = 99 and ult_status not= "E" then
	    for i : 1 .. 3
		ult_ind_radius := 1500
		for j : 1 .. round (fps)
		    ult_ind_radius -= round (1500 / (fps))
		    delay (round (1000 / fps))
		end for
	    end for
	    ult_ind_radius := 0
	end if
	exit when game_status = "L"
    end loop
end ult_indicator

process passive_reload          % replenishes ammo over time
    loop
	if ammo < 50 then
	    ammo += 1
	end if
	delay (round (120 - 60 * (upgrades (2) / 4)))
	exit when game_status = "L"
    end loop
end passive_reload

process passive_ult_gain        % increases ult charge over time
    loop
	if ult_charge < 100 and game_status = "game" then
	    ult_charge += 1
	else
	    text_blink_ind *= -1
	end if
	delay (round (800 - 400 * (upgrades (4) / 4)))
	exit when game_status = "L"
    end loop
end passive_ult_gain

process game_timer              % timer of 1 second; used to increase score and animate loss screen text
    loop
	if game_status = "game" and tutorial_phase = "end" then
	    delay (1000)
	    score += 1
	    if score mod 50 = 0 and score mod 100 not= 0 then
		boss_fight := true
	    end if
	    %elsif game_status not= "start" then
	elsif game_status = "L" then
	    for i : 1 .. 15
		delay (100)
		end_text_color_timer += 1
	    end for
	    exit
	end if
    end loop
end game_timer

process secondary_fire_timer    % controls rate of secondary firem independent of the rate of primary fire
    loop
	exit when game_status = "L"
	if not (secondary_fire_ready) then
	    delay (round (200 - 100 * (upgrades (3) / 4)))
	    secondary_fire_ready := true
	end if
    end loop
end secondary_fire_timer

process shoot_bullets           % collects mouse pointer information and fires a bullet based on pointer position and which button is pressed
    var bullet_delay_ind : int := 0
    loop
	Mouse.Where (mouse_x, mouse_y, shooting)
	if shooting = 1 and ammo > 0 and game_status = "game" then      % upon left click and if all conditions are met, shoot regular bullets
	    for i : 1 .. 50
		if not (moving (bullets (i))) then
		    bullets (i) (1) := 500
		    bullets (i) (2) := 140
		    if mouse_x = 500 then
			bullets (i) (3) := 0
			bullets (i) (4) := 1000
		    elsif mouse_x < 500 then
			bullets (i) (3) := -1000 * cos (arctan ((mouse_y - 140) / (mouse_x - 500)))
			bullets (i) (4) := -1000 * sin (arctan ((mouse_y - 140) / (mouse_x - 500)))
		    else
			bullets (i) (3) := 1000 * cos (arctan ((mouse_y - 140) / (mouse_x - 500)))
			bullets (i) (4) := 1000 * sin (arctan ((mouse_y - 140) / (mouse_x - 500)))
		    end if
		    ammo -= 1
		    exit
		end if
	    end for
	    bullet_delay_ind := 0
	end if
	if shooting = 100 and ammo > 9 and game_status = "game" then    % upon right click and if all conditions are met, shoot large bullet
	    if secondary_fire_ready then
		for i : 1 .. 50
		    if not (moving (bullets (i))) then
			bullets (i) (1) := 500
			bullets (i) (2) := 140
			bullets (i) (5) := 20
			if mouse_x = 500 then
			    bullets (i) (3) := 0
			    bullets (i) (4) := 800
			elsif mouse_x < 500 then
			    bullets (i) (3) := -800 * cos (arctan ((mouse_y - 140) / (mouse_x - 500)))
			    bullets (i) (4) := -800 * sin (arctan ((mouse_y - 140) / (mouse_x - 500)))
			else
			    bullets (i) (3) := 800 * cos (arctan ((mouse_y - 140) / (mouse_x - 500)))
			    bullets (i) (4) := 800 * sin (arctan ((mouse_y - 140) / (mouse_x - 500)))
			end if
			ammo -= 10
			exit
		    end if
		end for
		bullet_delay_ind := 1
		secondary_fire_ready := false
	    end if
	end if
	if ult_status = "L" then                % shoots bullets as visual effects when the ultimate ability is launched
	    Music.PlayFileReturn ("omae_wa.wav")
	    for i : 1 .. 25
		delay (20)
		bullets (i) (1) := 500
		bullets (i) (2) := 140
		bullets (i) (3) := 500 * cosd (7.2 * i)
		bullets (i) (4) := 500 * sind (7.2 * i)
		bullets (i) (5) := 10
	    end for
	    for decreasing i : 50 .. 26
		delay (20)
		bullets (i) (1) := 500
		bullets (i) (2) := 140
		bullets (i) (3) := 500 * cosd (7.2 * (i - 25))
		bullets (i) (4) := 500 * sind (7.2 * (i - 25))
		bullets (i) (5) := 10
	    end for
	    ult_status := "F"
	end if
	delay (round (50 - 25 * (upgrades (3) / 4)))
	exit when game_status = "L"
    end loop
end shoot_bullets

process deploy_ult                              % complete execution of ultimate ability and corresponding visual effects (this was a nightmare to debug)
    loop
	if input = " " and ult_charge not= 100 and not (ult_status = "L" or ult_status = "F" or ult_status = "E") then
	    input := ""
	elsif input = " " and ult_charge = 100 and not (ult_status = "L" or ult_status = "F" or ult_status = "E") then
	    ult_status := ""
	    for i : 1 .. upper (asteroids)
		asteroids (i) (3) := 0
		asteroids (i) (4) := 0
		asteroids (i) (7) := 0
	    end for
	    for i : 1 .. 5
		delay (200)
		colorback (26 - i)
	    end for
	    ult_status := "L"
	elsif (input = "" or input = " " or input = "1" or input = "2" or input = "3" or input = "4") and not (ult_status = "L" or ult_status = "F" or ult_status = "E") and game_status = "game"
		then
	    getch (input)
	    if not (input = " " or input = "1" or input = "2" or input = "3" or input = "4") or not (tutorial_phase = "end" or tutorial_phase = "upgrades") then
		input := ""
	    end if
	elsif ult_status = "F" then
	    for decreasing i : fps .. 1
		delay (round (1000 / fps))
		ult_attack_radius := round (((i - 1) / fps) * 1000)
	    end for
	    for i : 1 .. upper (asteroids)
		if asteroids (i) (6) not= 0 then
		    asteroids (i) (3) := 0
		    asteroids (i) (4) := 0
		end if
	    end for
	    ult_status := "E"
	elsif ult_status = "E" then
	    delay (1000)
	    for i : 0 .. 2 * fps
		delay (round (1000 / fps))
		ult_finish_radius := round ((i / (2 * fps)) * 2000)
	    end for
	    for i : 1 .. upper (asteroids)
		asteroids (i) (1) := -1000
		asteroids (i) (2) := -1000
		asteroids (i) (3) := 0
		asteroids (i) (4) := 0
		asteroids (i) (5) := 1
		asteroids (i) (6) := 0
		asteroids (i) (7) := 0
	    end for
	    boss_fight := false
	    end_boss_fight := false
	    delay (1000)
	    colorback (26)
	    ult_finish_radius := 0
	    text_blink_ind := 1
	    ammo := 50
	    for decreasing i : 99 .. 0
		delay (10)
		ult_charge := i
	    end for
	    ult_status := ""
	end if
	exit when game_status = "L"
    end loop
end deploy_ult

process launch_asteroid_wave
    % during regular gameplay, launches on of 6 available asteroids with a random x coordinate and random radius, with an initial trajectory directed at the player
    loop                                        % during boss fight, waits for all normal asteroids to be cleared, and launches a singles massive slow-moving asteroid
	if not (boss_fight) and game_status = "game" then
	    for i : 1 .. upper (asteroids)
		if score <= 900 then
		    delay (1000 - score)
		else
		    delay (100)
		end if
		if Rand.Int (0, 1) = 1 and asteroids (i) (6) = 0 then
		    asteroids (i) (5) := Rand.Int (20, 120)
		    asteroids (i) (1) := Rand.Int (100, 900)
		    asteroids (i) (2) := 1000 + asteroids (i) (5)
		    var overall_velocity : int := Rand.Int (round (30 + score), round (200 + score))
		    if asteroids (i) (1) = 500 then
			asteroids (i) (3) := 0
			asteroids (i) (4) := -overall_velocity
		    elsif asteroids (i) (1) > 500 then
			asteroids (i) (3) := -overall_velocity * cos (arctan ((asteroids (i) (2) - 140) / (asteroids (i) (1) - 500)))
			asteroids (i) (4) := -overall_velocity * sin (arctan ((asteroids (i) (2) - 140) / (asteroids (i) (1) - 500)))
		    else
			asteroids (i) (3) := overall_velocity * cos (arctan ((asteroids (i) (2) - 140) / (asteroids (i) (1) - 500)))
			asteroids (i) (4) := overall_velocity * sin (arctan ((asteroids (i) (2) - 140) / (asteroids (i) (1) - 500)))
		    end if
		    asteroids (i) (6) := 1
		end if
		exit when game_status = "L"
	    end for
	elsif ult_status not= "E" and game_status = "game" and boss_fight then
	    exit when game_status = "L"
	    var all_asteroids_set : boolean := true
	    for i : 1 .. 6
		if asteroids (i) (6) not= 0 then
		    all_asteroids_set := false
		end if
	    end for
	    if all_asteroids_set and not (end_boss_fight) then
		for i : 1 .. 5
		    delay (200)
		    colorback (26 - i)
		end for
		asteroids (1) (5) := 1000
		asteroids (1) (1) := Rand.Int (100, 900)
		asteroids (1) (2) := 1000 + asteroids (1) (5)
		var overall_velocity : int := 100
		if asteroids (1) (1) = 500 then
		    asteroids (1) (3) := 0
		    asteroids (1) (4) := -overall_velocity
		elsif asteroids (1) (1) > 500 then
		    asteroids (1) (3) := -overall_velocity * cos (arctan ((asteroids (1) (2) - 140) / (asteroids (1) (1) - 500)))
		    asteroids (1) (4) := -overall_velocity * sin (arctan ((asteroids (1) (2) - 140) / (asteroids (1) (1) - 500)))
		else
		    asteroids (1) (3) := overall_velocity * cos (arctan ((asteroids (1) (2) - 140) / (asteroids (1) (1) - 500)))
		    asteroids (1) (4) := overall_velocity * sin (arctan ((asteroids (1) (2) - 140) / (asteroids (1) (1) - 500)))
		end if
		asteroids (1) (6) := 2
	    elsif end_boss_fight then
		for i : 1 .. 5
		    delay (200)
		    colorback (21 + i)
		end for
		end_boss_fight := false
		boss_fight := false
	    end if
	end if
	exit when game_status = "L"
    end loop
end launch_asteroid_wave

process physics                                     % resets any asteroids or bullets that travel out of bounds, simulates bullet-asteroid collisions as a single specular reflection
    loop                                            % updates the positions of asteroids and bullets based on the velocities at a rate of fps
	for i : 1 .. upper (asteroids)
	    if sqrt ((500 - asteroids (i) (1)) ** 2 + (60 - asteroids (i) (2)) ** 2) < (100 + asteroids (i) (5)) then
		game_status := "L"
		Music.PlayFileStop
	    end if
	end for
	exit when game_status = "L"
	for i : 1 .. 50
	    if moving (bullets (i)) and (bullets (i) (1) > 1000 + bullets (i) (5) or bullets (i) (1) < -bullets (i) (5) or bullets (i) (2) > 1000 + bullets (i) (5) or bullets (i) (2) <
		    - bullets (i) (5)) then
		bullets (i) (1) := -25
		bullets (i) (2) := -25
		bullets (i) (3) := 0
		bullets (i) (4) := 0
		bullets (i) (5) := 8
	    end if
	end for
	for i : 1 .. upper (asteroids)
	    if asteroids (i) (6) = 1 and asteroids (i) (2) < -asteroids (i) (5) then
		asteroids (i) (1) := -1000
		asteroids (i) (2) := -1000
		asteroids (i) (3) := 0
		asteroids (i) (4) := 0
		asteroids (i) (5) := 1
		asteroids (i) (6) := 0
		asteroids (i) (7) := 0
	    elsif asteroids (i) (7) = 1 and (asteroids (i) (1) > 1000 + asteroids (i) (5) or asteroids (i) (1) < -asteroids (i) (5) or asteroids (i) (2) > 1000 + asteroids (i) (5) or
		    asteroids (i) (2) < -asteroids (i) (5)) then
		asteroids (i) (1) := -1000
		asteroids (i) (2) := -1000
		asteroids (i) (3) := 0
		asteroids (i) (4) := 0
		asteroids (i) (5) := 1
		asteroids (i) (6) := 0
		asteroids (i) (7) := 0
	    elsif asteroids (i) (7) = 1 then
		asteroids (i) (4) += g
	    elsif asteroids (i) (6) = 2 and (asteroids (i) (1) > 1000 + asteroids (i) (5) or asteroids (i) (1) < -asteroids (i) (5) or asteroids (i) (2) > 1000 + asteroids (i) (5) or
		    asteroids (i) (2) < -asteroids (i) (5)) then
		asteroids (i) (1) := -1000
		asteroids (i) (2) := -1000
		asteroids (i) (3) := 0
		asteroids (i) (4) := 0
		asteroids (i) (5) := 1
		asteroids (i) (6) := 0
		asteroids (i) (7) := 0
		end_boss_fight := true
	    end if
	end for

	for i : 1 .. upper (asteroids)
	    for j : 1 .. 50
		if sqrt ((asteroids (i) (1) - bullets (j) (1)) ** 2 + (asteroids (i) (2) - bullets (j) (2)) ** 2) <= asteroids (i) (5) + bullets (j) (5) and bullets (j) (5) not= 10 then
		    if (bullets (j) (1) - asteroids (i) (1) not= 0 or bullets (j) (2) - asteroids (i) (2) not= 0) and (bullets (j) (3) not= 0 or bullets (j) (4) not= 0) then
			var normal : array 1 .. 2 of real
			normal (1) := unit_multiple (bullets (j) (1) - asteroids (i) (1), bullets (j) (2) - asteroids (i) (2)) * (bullets (j) (1) - asteroids (i) (1))
			normal (2) := unit_multiple (bullets (j) (1) - asteroids (i) (1), bullets (j) (2) - asteroids (i) (2)) * (bullets (j) (2) - asteroids (i) (2))

			var incident : array 1 .. 2 of real
			incident (1) := -unit_multiple (bullets (j) (3), bullets (j) (4)) * bullets (j) (3)
			incident (2) := -unit_multiple (bullets (j) (3), bullets (j) (4)) * bullets (j) (4)

			var final : array 1 .. 2 of real
			final (1) := sqrt (bullets (j) (3) ** 2 + bullets (j) (4) ** 2) * (2 * (normal (1) * incident (1) + normal (2) * incident (2)) * normal (1) - incident (1))
			final (2) := sqrt (bullets (j) (3) ** 2 + bullets (j) (4) ** 2) * (2 * (normal (1) * incident (1) + normal (2) * incident (2)) * normal (2) - incident (2))
			bullets (j) (3) := final (1)
			bullets (j) (4) := final (2)
			if bullets (j) (5) = 8 then
			    asteroids (i) (3) -= (upgrades (1) / 4 + 1) * 90 * bullets (j) (5) * normal (1) / asteroids (i) (5)
			    asteroids (i) (4) -= (upgrades (1) / 4 + 1) * 90 * bullets (j) (5) * normal (2) / asteroids (i) (5)
			else
			    asteroids (i) (3) -= (upgrades (1) / 4 + 1) * 500 * bullets (j) (5) * normal (1) / asteroids (i) (5)
			    asteroids (i) (4) -= (upgrades (1) / 4 + 1) * 500 * bullets (j) (5) * normal (2) / asteroids (i) (5)
			end if

			% adjust overlap
			bullets (j) (1) += normal (1)
			bullets (j) (2) += normal (2)

			if asteroids (i) (6) = 1 then
			    asteroids (i) (7) := 1
			end if
		    end if
		end if
	    end for
	end for

	if game_status = "game" then
	    for i : 1 .. 50
		bullets (i) (1) += bullets (i) (3) / fps
		bullets (i) (2) += bullets (i) (4) / fps
	    end for
	    if not (ult_status = "L" or ult_status = "F" or ult_status = "E") then
		for i : 1 .. upper (asteroids)
		    asteroids (i) (1) += asteroids (i) (3) / fps
		    asteroids (i) (2) += asteroids (i) (4) / fps
		end for
	    end if
	end if
	delay (round (1000 / fps))
	exit when game_status = "L"
    end loop
end physics

%%%%%%%%%%%%%%%%%%%%%% MAIN CODE %%%%%%%%%%%%%%%%%%%%%%%%%%
Mouse.ButtonChoose ("multibutton")                          % allows different mouse buttons to be registered uniquely
setscreen ("graphics:1000;1000,nocursor,offscreenonly")     % 1000 x 1000 window; off-screen update only to ensure smooth animation

loop                                                        % infinite loop of play game, lose, restart
    game_status := "start"                                  % initializ processes
    colorback (26)                                          % set initial background color

    fork play_music                                         % combination of all processes to form main code
    fork tutorial
    fork game_timer
    fork secondary_fire_timer
    fork upgrades_menu
    fork perform_upgrades
    fork passive_ult_gain
    fork passive_reload
    fork deploy_ult
    fork shoot_bullets
    fork launch_asteroid_wave
    fork physics
    fork ult_indicator
    fork loss_screen_controls
    fork draw_game

    loop                                                    % once the forked processes end, end screen code starts
	if game_status = "restart" then                     % reset all settings when game is restarted
	    input := ""
	    ult_status := ""
	    upgrade_points := 0
	    upgrade_menu_position := 300
	    ammo := 50
	    score := 0
	    for i : 1 .. 4
		upgrades (i) := 0
	    end for
	    ult_charge := 0
	    ult_ind_radius := 0
	    ult_attack_radius := 0
	    ult_finish_radius := 0
	    text_blink_ind := 1
	    tutorial_proceed := false
	    tutorial_text_color := 26
	    tutorial_phase := "LMB"
	    end_text_color_timer := 16
	    mouse_x := 0
	    mouse_y := 0
	    shooting := 0
	    secondary_fire_ready := true
	    boss_fight := false
	    end_boss_fight := false
	    for i : 1 .. 50
		bullets (i) (1) := -25
		bullets (i) (2) := -25
		bullets (i) (3) := 0
		bullets (i) (4) := 0
		bullets (i) (5) := 8
	    end for
	    for i : 1 .. upper (asteroids)
		asteroids (i) (1) := -1000
		asteroids (i) (2) := -1000
		asteroids (i) (3) := 0
		asteroids (i) (4) := 0
		asteroids (i) (5) := 1
		asteroids (i) (6) := 0
		asteroids (i) (7) := 0
	    end for
	    delay (500)
	    cls
	    exit
	end if
    end loop
end loop
