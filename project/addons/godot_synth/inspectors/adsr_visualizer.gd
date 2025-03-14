@tool
extends Control

var adsr: ADSR
var points = []
var sustain_duration = 0.5 # Fixed duration for sustain in visualization

func _init(p_adsr: ADSR):
    adsr = p_adsr
    custom_minimum_size = Vector2(0, 80) # Set minimum height
    _generate_points()

func update():
    _generate_points()
    queue_redraw()

func _generate_points():
    points.clear()
    
    if not adsr:
        return
    
    var attack = adsr.get_attack()
    var decay = adsr.get_decay()
    var sustain = adsr.get_sustain()
    var release = adsr.get_release()
    
    var attack_type = adsr.get_attack_type()
    var decay_type = adsr.get_decay_type()
    var release_type = adsr.get_release_type()
    
    var total_time = attack + decay + sustain_duration + release
    var time_scale = 1.0 / total_time
    
    # Start point (0,0)
    points.append(Vector2(0, 0))
    
    # Generate attack points
    var attack_points = 10
    for i in range(1, attack_points + 1):
        var t = float(i) / attack_points
        var time = attack * t * time_scale
        var value
        
        match attack_type:
            ADSR.LINEAR:
                value = t
            ADSR.EXPONENTIAL:
                value = pow(t, 2)
            ADSR.LOGARITHMIC:
                value = sqrt(t)
        
        points.append(Vector2(time, value))
    
    # Generate decay points
    var decay_points = 10
    for i in range(0, decay_points + 1):
        var t = float(i) / decay_points
        var time = attack * time_scale + decay * t * time_scale
        var value
        
        match decay_type:
            ADSR.LINEAR:
                value = lerp(1.0, sustain, t)
            ADSR.EXPONENTIAL:
                value = lerp(1.0, sustain, pow(t, 2))
            ADSR.LOGARITHMIC:
                value = lerp(1.0, sustain, sqrt(t))
        
        points.append(Vector2(time, value))
    
    # Sustain point
    var sustain_time = (attack + decay + sustain_duration) * time_scale
    points.append(Vector2(sustain_time, sustain))
    
    # Generate release points
    var release_points = 10
    for i in range(0, release_points + 1):
        var t = float(i) / release_points
        var time = sustain_time + release * t * time_scale
        var value
        
        match release_type:
            ADSR.LINEAR:
                value = lerp(sustain, 0.0, t)
            ADSR.EXPONENTIAL:
                value = lerp(sustain, 0.0, pow(t, 2))
            ADSR.LOGARITHMIC:
                value = lerp(sustain, 0.0, sqrt(t))
        
        points.append(Vector2(time, value))

func _draw():
    if points.size() < 2:
        return
    
    var rect = Rect2(Vector2.ZERO, size)
    var padding = 10
    var draw_rect = Rect2(
        Vector2(padding, padding),
        Vector2(rect.size.x - padding * 2, rect.size.y - padding * 2)
    )
    
    # Draw background
    var bg_color = Color(0.2, 0.2, 0.2, 0.5)
    draw_rect(draw_rect, bg_color)
    
    # Draw envelope
    var prev_point = null
    for i in range(points.size()):
        var point = points[i]
        var x = draw_rect.position.x + point.x * draw_rect.size.x
        # Map value from 0,1 to draw_rect y coordinates (inverted)
        var y = draw_rect.position.y + draw_rect.size.y - point.y * draw_rect.size.y
        
        if prev_point != null:
            draw_line(prev_point, Vector2(x, y), Color.WHITE, 2)
        
        prev_point = Vector2(x, y)
    
    # Draw stage labels
    var font = get_theme_default_font()
    var font_size = get_theme_default_font_size()
    
    if points.size() >= 5:
        # Attack label
        var attack_x = (points[0].x + points[1].x) / 2 * draw_rect.size.x + draw_rect.position.x
        draw_string(font, Vector2(attack_x, draw_rect.position.y + draw_rect.size.y + 15), "A", HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.WHITE)
        
        # Decay label
        var decay_x = (points[1].x + points[2].x) / 2 * draw_rect.size.x + draw_rect.position.x
        draw_string(font, Vector2(decay_x, draw_rect.position.y + draw_rect.size.y + 15), "D", HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.WHITE)
        
        # Sustain label
        var sustain_x = (points[2].x + points[3].x) / 2 * draw_rect.size.x + draw_rect.position.x
        draw_string(font, Vector2(sustain_x, draw_rect.position.y + draw_rect.size.y + 15), "S", HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.WHITE)
        
        # Release label
        var release_x = (points[3].x + points[4].x) / 2 * draw_rect.size.x + draw_rect.position.x
        draw_string(font, Vector2(release_x, draw_rect.position.y + draw_rect.size.y + 15), "R", HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.WHITE)