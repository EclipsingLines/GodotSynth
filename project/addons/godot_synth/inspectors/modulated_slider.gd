@tool
extends Control

# Import the ModulationType enum constants
const MODULATION_ADDITIVE = 0
const MODULATION_MULTIPLICATIVE = 1
const MODULATION_ABSOLUTE = 2
const MODULATION_GATE = 3

var parameter: ModulatedParameter
var updating = false

func _init(param: ModulatedParameter):
    parameter = param
    
    # Set minimum height for drawing the modulation range
    custom_minimum_size = Vector2(0, 50)

func update_from_parameter():
    updating = true
    updating = false
    queue_redraw() # Redraw to update the modulation visualization

func _draw():
    # Get the control's rect
    var local_rect = Rect2(Vector2.ZERO, size)
    
    # Calculate the normalized positions
    var min_val = parameter.get_mod_min()
    var max_val = parameter.get_mod_max()
    var range_val = max_val - min_val
    
    # Get modulation parameters
    var base_value = parameter.get_base_value()
    var mod_amount = parameter.get_mod_amount()
    var mod_type = parameter.get_mod_type()
    var invert_mod = parameter.get_invert_mod()
    
    # Calculate the modulation range based on modulation type
    var mod_min = base_value
    var mod_max = base_value
    
    match mod_type:
        MODULATION_ADDITIVE:
            mod_min = base_value - (1 if invert_mod else 0) * mod_amount
            mod_max = base_value + (0 if invert_mod else 1) * mod_amount
        
        MODULATION_MULTIPLICATIVE:
            # For LFOs (-1 to 1), show full range around base value
            var factor = 1.0 + mod_amount
            if invert_mod:
                mod_min = base_value / factor
                mod_max = base_value
            else:
                # Show full range for LFO modulation (-1 to 1)
                mod_min = base_value * (1.0 - mod_amount) # LFO at -1
                mod_max = base_value * (1.0 + mod_amount) # LFO at +1
        
        MODULATION_ABSOLUTE:
            # For standard use
            var standard_min = min(base_value, mod_amount)
            var standard_max = max(base_value, mod_amount)
            
            # For LFOs (-1 to 1), show full range
            var lfo_min = base_value - mod_amount # LFO at -1
            var lfo_max = base_value + mod_amount # LFO at +1
            
            # Use the wider range of the two calculations
            mod_min = min(standard_min, lfo_min)
            mod_max = max(standard_max, lfo_max)
        
        MODULATION_GATE:
            mod_min = base_value
            mod_max = base_value + (mod_amount if not invert_mod else 0.0)
    
    # Clamp to parameter min/max
    mod_min = clamp(mod_min, min_val, max_val)
    mod_max = clamp(mod_max, min_val, max_val)
    
    # Convert to normalized positions (0-1)
    var norm_min = (mod_min - min_val) / range_val if range_val > 0 else 0
    var norm_max = (mod_max - min_val) / range_val if range_val > 0 else 1
    var norm_base = (base_value - min_val) / range_val if range_val > 0 else 0.5
    
    # Calculate positions on the visualization
    var padding = 10 # Padding on both sides
    var usable_width = local_rect.size.x - (padding * 2)
    
    var min_x = padding + (norm_min * usable_width)
    var max_x = padding + (norm_max * usable_width)
    var base_x = padding + (norm_base * usable_width)
    
    # Draw background
    var bg_color = Color(0.2, 0.2, 0.2, 0.5)
    draw_rect(Rect2(padding, 5, usable_width, local_rect.size.y - 25), bg_color)
    
    # Draw the modulation range
    var mod_color = Color(0.2, 0.6, 1.0, 0.3) # Light blue with transparency
    draw_rect(Rect2(min_x, 5, max_x - min_x, local_rect.size.y - 25), mod_color)
    
    # Draw a line at the base value position
    draw_line(Vector2(base_x, 5), Vector2(base_x, local_rect.size.y - 20), Color.WHITE, 2)
    
    # Draw markers at 0%, 33%, 66%, and 100%
    var font = get_theme_default_font()
    var font_size = get_theme_default_font_size()
    var marker_positions = [0.0, 0.33, 0.66, 1.0]
    
    for pos in marker_positions:
        var marker_x = padding + (pos * usable_width)
        var marker_value = min_val + pos * range_val
        var marker_text = str(snappedf(marker_value, 0.01))
        
        # Draw tick mark
        draw_line(Vector2(marker_x, local_rect.size.y - 20), Vector2(marker_x, local_rect.size.y - 15), Color.WHITE, 1)
        
        # Draw value text
        var text_size = font.get_string_size(marker_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
        draw_string(font, Vector2(marker_x - text_size.x / 2, local_rect.size.y - 5), marker_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.WHITE)