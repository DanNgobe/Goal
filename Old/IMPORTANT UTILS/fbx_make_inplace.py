import fbx
import FbxCommon
import sys


def find_root_bone(scene, debug=False):
    """
    Find the root bone (Hips) in the skeleton hierarchy.
    Mixamo rigs typically have a structure like: Armature -> Hips -> ...
    """
    root_node = scene.GetRootNode()
    
    # Search for common root bone names
    root_bone_names = ["Hips", "mixamorig:Hips", "Root", "root"]
    
    candidates = []
    
    def search_node(node, depth=0):
        node_name = node.GetName()
        node_attr = node.GetNodeAttribute()
        
        if debug:
            attr_name = "None"
            if node_attr:
                attr_type = node_attr.GetAttributeType()
                attr_name = node_attr.GetTypeName()
            print("  " * depth + f"{node_name} [{attr_name}]")
        
        # Check if this is a root bone
        for bone_name in root_bone_names:
            if bone_name.lower() in node_name.lower():
                # Verify it's a skeleton node
                if node_attr:
                    attr_type = node_attr.GetAttributeType()
                    try:
                        if attr_type == fbx.FbxNodeAttribute.EType.eSkeleton:
                            candidates.append(node)
                            return node
                    except AttributeError:
                        # Try without EType
                        if attr_type == fbx.FbxNodeAttribute.eSkeleton:
                            candidates.append(node)
                            return node
        
        # Search children
        for i in range(node.GetChildCount()):
            result = search_node(node.GetChild(i), depth + 1)
            if result:
                return result
        
        return None
    
    result = search_node(root_node)
    
    # If we didn't find it by skeleton type, just look for name match
    if not result and candidates:
        return candidates[0]
    
    return result


def get_animation_stack(scene):
    """Get the first animation stack in the scene."""
    num_stacks = scene.GetSrcObjectCount(fbx.FbxCriteria.ObjectType(fbx.FbxAnimStack.ClassId))
    if num_stacks > 0:
        return scene.GetSrcObject(fbx.FbxCriteria.ObjectType(fbx.FbxAnimStack.ClassId), 0)
    return None


def make_animation_inplace(scene, root_bone, remove_forward=True, remove_lateral=True, remove_upward=False):
    """
    Remove translation from the root bone to make animation in-place.
    
    Args:
        scene: FBX scene
        root_bone: The root bone node (typically Hips)
        remove_forward: Remove Z-axis translation (forward/backward in Mixamo)
        remove_lateral: Remove X-axis translation (left/right)
        remove_upward: Remove Y-axis translation (up/down)
    """
    anim_stack = get_animation_stack(scene)
    if not anim_stack:
        print("No animation found in scene")
        return False
    
    # Set the current animation stack
    scene.SetCurrentAnimationStack(anim_stack)
    
    # Get the animation layer (first layer)
    anim_layer = anim_stack.GetMember(fbx.FbxCriteria.ObjectType(fbx.FbxAnimLayer.ClassId), 0)
    if not anim_layer:
        print("No animation layer found")
        return False
    
    # Get the animation curve nodes for translation
    lcl_translation = root_bone.LclTranslation
    
    # Get animation curves for each axis
    curve_x = lcl_translation.GetCurve(anim_layer, "X")
    curve_y = lcl_translation.GetCurve(anim_layer, "Y")  
    curve_z = lcl_translation.GetCurve(anim_layer, "Z")
    
    # Get time span
    time_span = anim_stack.GetLocalTimeSpan()
    start_time = time_span.GetStart()
    stop_time = time_span.GetStop()
    
    # Get frame rate
    frame_rate = fbx.FbxTime.GetFrameRate(scene.GetGlobalSettings().GetTimeMode())
    
    # Calculate number of frames
    start_frame = int(start_time.GetFrameCount(scene.GetGlobalSettings().GetTimeMode()))
    stop_frame = int(stop_time.GetFrameCount(scene.GetGlobalSettings().GetTimeMode()))
    
    print(f"\nAnimation Info:")
    print(f"  Frame range: {start_frame} to {stop_frame}")
    print(f"  Frame rate: {frame_rate}")
    print(f"  Root bone: {root_bone.GetName()}")
    
    # Store initial Y value if we want to preserve height
    initial_y = None
    if not remove_upward and curve_y and curve_y.KeyGetCount() > 0:
        # Get the value from the first key instead of using Evaluate
        initial_y = curve_y.KeyGetValue(0)
    
    # Process each frame
    for frame in range(start_frame, stop_frame + 1):
        time = fbx.FbxTime()
        time.SetFrame(frame, scene.GetGlobalSettings().GetTimeMode())
        
        # Remove lateral movement (X-axis)
        if remove_lateral and curve_x:
            curve_x.KeyModifyBegin()
            key_index, _ = curve_x.KeyAdd(time)  # Returns (index, was_created)
            curve_x.KeySetValue(key_index, 0.0)
            curve_x.KeyModifyEnd()
        
        # Remove upward movement (Y-axis) or set to constant height
        if curve_y:
            curve_y.KeyModifyBegin()
            key_index, _ = curve_y.KeyAdd(time)  # Returns (index, was_created)
            if remove_upward:
                curve_y.KeySetValue(key_index, 0.0)
            elif initial_y is not None:
                curve_y.KeySetValue(key_index, initial_y)
            curve_y.KeyModifyEnd()
        
        # Remove forward movement (Z-axis in Mixamo/Blender coordinate system)
        if remove_forward and curve_z:
            curve_z.KeyModifyBegin()
            key_index, _ = curve_z.KeyAdd(time)  # Returns (index, was_created)
            curve_z.KeySetValue(key_index, 0.0)
            curve_z.KeyModifyEnd()
    
    print(f"\nProcessed {stop_frame - start_frame + 1} frames")
    print(f"  Removed lateral (X): {remove_lateral}")
    print(f"  Removed upward (Y): {remove_upward}")
    print(f"  Removed forward (Z): {remove_forward}")
    
    return True


def main():
    if len(sys.argv) < 3:
        print("Usage: python fbx_make_inplace.py <input.fbx> <output.fbx> [mode] [--debug]")
        print("\nModes:")
        print("  forward   - Remove forward movement only")
        print("  lateral   - Remove lateral movement only")
        print("  both      - Remove both forward and lateral (default)")
        print("  all       - Remove forward, lateral, and upward")
        print("\nOptions:")
        print("  --debug   - Show scene hierarchy for debugging")
        return
    
    input_file = sys.argv[1]
    output_file = sys.argv[2]
    mode = "both"
    debug = False
    
    # Parse arguments
    for arg in sys.argv[3:]:
        if arg == "--debug":
            debug = True
        else:
            mode = arg.lower()
    
    # Initialize FBX SDK
    manager, scene = FbxCommon.InitializeSdkObjects()
    
    # Load the FBX file
    print(f"Loading {input_file}...")
    result = FbxCommon.LoadScene(manager, scene, input_file)
    if not result:
        print(f"Failed to load {input_file}")
        manager.Destroy()
        return
    
    print("Scene loaded successfully")
    
    if debug:
        print("\n=== Scene Hierarchy ===")
    
    # Find the root bone
    root_bone = find_root_bone(scene, debug=debug)
    if not root_bone:
        print("\nCould not find root bone (Hips). Make sure this is a Mixamo rig.")
        print("Try running with --debug to see the scene hierarchy")
        manager.Destroy()
        return
    
    # Determine which axes to zero based on mode
    remove_forward = mode in ["forward", "both", "all"]
    remove_lateral = mode in ["lateral", "both", "all"]
    remove_upward = mode == "all"
    
    # Make animation in-place
    print(f"\nMaking animation in-place (mode: {mode})...")
    success = make_animation_inplace(scene, root_bone, remove_forward, remove_lateral, remove_upward)
    
    if not success:
        print("Failed to process animation")
        manager.Destroy()
        return
    
    # Save the modified FBX
    print(f"\nSaving to {output_file}...")
    result = FbxCommon.SaveScene(manager, scene, output_file)
    
    if result:
        print("Success! Animation is now in-place.")
    else:
        print("Failed to save output file")
    
    # Cleanup
    manager.Destroy()


if __name__ == "__main__":
    main()