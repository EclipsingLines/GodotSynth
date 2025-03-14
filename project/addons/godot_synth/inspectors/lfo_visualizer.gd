@tool
extends Control

var lfo: LFO
var points = []
var sample_count = 100 # Number of points to sample

func _init(p_lfo: LFO):
    lfo = p_lfo
    custom_minimum_size = Vector2(0, 80) # Set minimum height
    _generate_points()

func update():
    _generate_points()
    queue_redraw()

func _generate_points():
    points.clear()
    
    if not lfo:
        return
    
    # Sample LFO over 1 second
    for i in range(sample_count):
        var time = float(i) / float(sample_count - 1) # 0 to 1 second
        var value = lfo.process(time)
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
    
    # Draw center line (zero value)
    var center_y = draw_rect.position.y + draw_rect.size.y / 2
    draw_line(
        Vector2(draw_rect.position.x, center_y),
        Vector2(draw_rect.position.x + draw_rect.size.x, center_y),
        Color(0.5, 0.5, 0.5, 0.5)
    )
    
    # Draw waveform
    var prev_point = null
    for i in range(points.size()):
        var point = points[i]
        var x = draw_rect.position.x + point.x * draw_rect.size.x
        # Map value from -1,1 to draw_rect y coordinates (inverted)
        var y = draw_rect.position.y + draw_rect.size.y / 2 - point.y * draw_rect.size.y / 2
        
        if prev_point != null:
            draw_line(prev_point, Vector2(x, y), Color.WHITE, 2)
        
        prev_point = Vector2(x, y)
