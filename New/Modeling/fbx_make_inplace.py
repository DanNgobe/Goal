import fbx
import FbxCommon
import sys


def find_node_by_name(scene, name, debug=False):
    """
    Find a node in the scene by exact name match.
    Falls back to a case-insensitive search if no exact match is found.
    """
    root_node = scene.GetRootNode()

    def search_node(node, depth=0):
        node_name = node.GetName()
        node_attr = node.GetNodeAttribute()

        if debug:
            attr_name = node_attr.GetTypeName() if node_attr else "None"
            print("  " * depth + f"{node_name} [{attr_name}]")

        if node_name == name:
            return node

        for i in range(node.GetChildCount()):
            result = search_node(node.GetChild(i), depth + 1)
            if result:
                return result

        return None

    # Try exact match first
    result = search_node(root_node)
    if result:
        return result

    # Fall back to case-insensitive match
    def search_icase(node):
        if node.GetName().lower() == name.lower():
            return node
        for i in range(node.GetChildCount()):
            r = search_icase(node.GetChild(i))
            if r:
                return r
        return None

    return search_icase(root_node)


def get_animation_stack(scene):
    """Get the first animation stack in the scene."""
    num_stacks = scene.GetSrcObjectCount(fbx.FbxCriteria.ObjectType(fbx.FbxAnimStack.ClassId))
    if num_stacks > 0:
        return scene.GetSrcObject(fbx.FbxCriteria.ObjectType(fbx.FbxAnimStack.ClassId), 0)
    return None


def make_animation_inplace(scene, target_node, remove_forward=True, remove_lateral=True, remove_upward=False):
    """
    Remove translation from target_node to make animation in-place.
    Targets LowerTorso (where fbx_transfer_armature_to_lowertorso.py writes
    the root translation), preserving Y so the character stays grounded.

    Args:
        scene: FBX scene
        target_node: The node whose translation curves will be zeroed (LowerTorso)
        remove_forward: Remove Z-axis translation (forward/backward)
        remove_lateral: Remove X-axis translation (left/right)
        remove_upward: Remove Y-axis translation (up/down) — keep False to preserve height
    """
    anim_stack = get_animation_stack(scene)
    if not anim_stack:
        print("No animation found in scene")
        return False

    scene.SetCurrentAnimationStack(anim_stack)

    anim_layer = anim_stack.GetMember(fbx.FbxCriteria.ObjectType(fbx.FbxAnimLayer.ClassId), 0)
    if not anim_layer:
        print("No animation layer found")
        return False

    lcl_translation = target_node.LclTranslation

    curve_x = lcl_translation.GetCurve(anim_layer, "X")
    curve_y = lcl_translation.GetCurve(anim_layer, "Y")
    curve_z = lcl_translation.GetCurve(anim_layer, "Z")

    time_span   = anim_stack.GetLocalTimeSpan()
    start_time  = time_span.GetStart()
    stop_time   = time_span.GetStop()
    time_mode   = scene.GetGlobalSettings().GetTimeMode()
    frame_rate  = fbx.FbxTime.GetFrameRate(time_mode)
    start_frame = int(start_time.GetFrameCount(time_mode))
    stop_frame  = int(stop_time.GetFrameCount(time_mode))

    print(f"\nAnimation Info:")
    print(f"  Frame range: {start_frame} to {stop_frame}")
    print(f"  Frame rate: {frame_rate}")
    print(f"  Target node: {target_node.GetName()}")

    # Preserve the first-frame Y value so the character stays at its rest height
    initial_y = None
    if not remove_upward and curve_y and curve_y.KeyGetCount() > 0:
        initial_y = curve_y.KeyGetValue(0)
        print(f"  Preserving Y at: {initial_y:.4f}")

    for frame in range(start_frame, stop_frame + 1):
        time = fbx.FbxTime()
        time.SetFrame(frame, time_mode)

        if remove_lateral and curve_x:
            curve_x.KeyModifyBegin()
            key_index, _ = curve_x.KeyAdd(time)
            curve_x.KeySetValue(key_index, 0.0)
            curve_x.KeyModifyEnd()

        if curve_y:
            curve_y.KeyModifyBegin()
            key_index, _ = curve_y.KeyAdd(time)
            if remove_upward:
                curve_y.KeySetValue(key_index, 0.0)
            elif initial_y is not None:
                curve_y.KeySetValue(key_index, initial_y)
            curve_y.KeyModifyEnd()

        if remove_forward and curve_z:
            curve_z.KeyModifyBegin()
            key_index, _ = curve_z.KeyAdd(time)
            curve_z.KeySetValue(key_index, 0.0)
            curve_z.KeyModifyEnd()

    print(f"\nProcessed {stop_frame - start_frame + 1} frames")
    print(f"  Removed lateral (X): {remove_lateral}")
    print(f"  Removed upward  (Y): {remove_upward}")
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

    # Target LowerTorso — this is where fbx_transfer_armature_to_lowertorso.py
    # writes the root translation keys. Zeroing X/Z here makes the animation in-place.
    target_node = find_node_by_name(scene, "LowerTorso", debug=debug)
    if not target_node:
        print("\nERROR: Could not find LowerTorso node.")
        print("Make sure fbx_transfer_armature_to_lowertorso.py has been run first.")
        print("Try running with --debug to see the scene hierarchy.")
        manager.Destroy()
        return
    
    # Determine which axes to zero based on mode
    remove_forward = mode in ["forward", "both", "all"]
    remove_lateral = mode in ["lateral", "both", "all"]
    remove_upward = mode == "all"
    
    # Make animation in-place
    print(f"\nMaking animation in-place (mode: {mode})...")
    success = make_animation_inplace(scene, target_node, remove_forward, remove_lateral, remove_upward)
    
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