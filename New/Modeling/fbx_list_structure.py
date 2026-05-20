import fbx
import FbxCommon
import sys


def get_node_attribute_info(node):
    """Get detailed information about a node's attributes."""
    node_attr = node.GetNodeAttribute()
    if not node_attr:
        return "None", "No attribute"
    
    attr_type = node_attr.GetAttributeType()
    
    # Try different ways to access attribute constants (SDK version compatibility)
    def get_attr_constant(name):
        # Try EType enum first (newer SDK)
        try:
            return getattr(fbx.FbxNodeAttribute.EType, name)
        except AttributeError:
            pass
        
        # Try direct attribute access (older SDK)
        try:
            return getattr(fbx.FbxNodeAttribute, name)
        except AttributeError:
            pass
        
        return None
    
    # Map attribute types to readable names
    attr_types = {}
    
    # Build the mapping dynamically based on what's available
    attr_names = [
        ("eUnknown", "Unknown"),
        ("eNull", "Null"),
        ("eMarker", "Marker"),
        ("eSkeleton", "Skeleton"),
        ("eMesh", "Mesh"),
        ("eNurbs", "Nurbs"),
        ("ePatch", "Patch"),
        ("eCamera", "Camera"),
        ("eCameraStereo", "Stereo Camera"),
        ("eCameraSwitcher", "Camera Switcher"),
        ("eLight", "Light"),
        ("eOpticalReference", "Optical Reference"),
        ("eOpticalMarker", "Optical Marker"),
        ("eNurbsCurve", "Nurbs Curve"),
        ("eTrimNurbsSurface", "Trim Nurbs Surface"),
        ("eBoundary", "Boundary"),
        ("eNurbsSurface", "Nurbs Surface"),
        ("eShape", "Shape"),
        ("eLODGroup", "LOD Group"),
        ("eSubDiv", "SubDiv")
    ]
    
    for const_name, display_name in attr_names:
        const_value = get_attr_constant(const_name)
        if const_value is not None:
            attr_types[const_value] = display_name
    
    attr_name = attr_types.get(attr_type, f"Unknown({attr_type})")
    
    # Get additional info based on type
    extra_info = ""
    mesh_type = get_attr_constant("eMesh")
    skeleton_type = get_attr_constant("eSkeleton")
    
    if mesh_type and attr_type == mesh_type:
        mesh = node_attr
        if hasattr(mesh, 'GetPolygonCount') and hasattr(mesh, 'GetControlPointsCount'):
            poly_count = mesh.GetPolygonCount()
            vertex_count = mesh.GetControlPointsCount()
            extra_info = f" ({vertex_count} vertices, {poly_count} polygons)"
    elif skeleton_type and attr_type == skeleton_type:
        skeleton = node_attr
        if hasattr(skeleton, 'GetSkeletonType'):
            skel_type = skeleton.GetSkeletonType()
            # Try to get skeleton type constants
            skel_types = {}
            skel_type_names = [
                ("eRoot", "Root"),
                ("eLimb", "Limb"),
                ("eLimbNode", "Limb Node"),
                ("eEffector", "Effector")
            ]
            
            for const_name, display_name in skel_type_names:
                try:
                    const_value = getattr(fbx.FbxSkeleton, const_name)
                    skel_types[const_value] = display_name
                except AttributeError:
                    pass
            
            extra_info = f" ({skel_types.get(skel_type, 'Unknown')})"
    
    return attr_name, extra_info


def get_animation_info(node, scene):
    """Get animation information for a node."""
    anim_info = []
    
    # Check if node has animation
    lcl_translation = node.LclTranslation
    lcl_rotation = node.LclRotation
    lcl_scaling = node.LclScaling
    
    # Get current animation stack
    anim_stack = None
    num_stacks = scene.GetSrcObjectCount(fbx.FbxCriteria.ObjectType(fbx.FbxAnimStack.ClassId))
    if num_stacks > 0:
        anim_stack = scene.GetSrcObject(fbx.FbxCriteria.ObjectType(fbx.FbxAnimStack.ClassId), 0)
        anim_layer = anim_stack.GetMember(fbx.FbxCriteria.ObjectType(fbx.FbxAnimLayer.ClassId), 0)
        
        if anim_layer:
            # Check for translation curves
            if (lcl_translation.GetCurve(anim_layer, "X") or 
                lcl_translation.GetCurve(anim_layer, "Y") or 
                lcl_translation.GetCurve(anim_layer, "Z")):
                anim_info.append("T")
            
            # Check for rotation curves
            if (lcl_rotation.GetCurve(anim_layer, "X") or 
                lcl_rotation.GetCurve(anim_layer, "Y") or 
                lcl_rotation.GetCurve(anim_layer, "Z")):
                anim_info.append("R")
            
            # Check for scaling curves
            if (lcl_scaling.GetCurve(anim_layer, "X") or 
                lcl_scaling.GetCurve(anim_layer, "Y") or 
                lcl_scaling.GetCurve(anim_layer, "Z")):
                anim_info.append("S")
    
    return anim_info


def list_materials(scene):
    """List all materials in the scene."""
    print("\n=== MATERIALS ===")
    material_count = scene.GetMaterialCount()
    if material_count == 0:
        print("No materials found")
        return
    
    for i in range(material_count):
        material = scene.GetMaterial(i)
        print(f"  {i}: {material.GetName()}")


def list_textures(scene):
    """List all textures in the scene."""
    print("\n=== TEXTURES ===")
    texture_count = scene.GetTextureCount()
    if texture_count == 0:
        print("No textures found")
        return
    
    for i in range(texture_count):
        texture = scene.GetTexture(i)
        print(f"  {i}: {texture.GetName()}")
        if hasattr(texture, 'GetFileName'):
            filename = texture.GetFileName()
            if filename:
                print(f"      File: {filename}")


def list_animations(scene):
    """List all animation stacks in the scene."""
    print("\n=== ANIMATIONS ===")
    num_stacks = scene.GetSrcObjectCount(fbx.FbxCriteria.ObjectType(fbx.FbxAnimStack.ClassId))
    
    if num_stacks == 0:
        print("No animations found")
        return
    
    for i in range(num_stacks):
        anim_stack = scene.GetSrcObject(fbx.FbxCriteria.ObjectType(fbx.FbxAnimStack.ClassId), i)
        print(f"  {i}: {anim_stack.GetName()}")
        
        # Get time span
        time_span = anim_stack.GetLocalTimeSpan()
        start_time = time_span.GetStart()
        stop_time = time_span.GetStop()
        
        # Get frame info
        start_frame = int(start_time.GetFrameCount(scene.GetGlobalSettings().GetTimeMode()))
        stop_frame = int(stop_time.GetFrameCount(scene.GetGlobalSettings().GetTimeMode()))
        frame_rate = fbx.FbxTime.GetFrameRate(scene.GetGlobalSettings().GetTimeMode())
        
        duration = (stop_frame - start_frame + 1) / frame_rate
        
        print(f"      Frames: {start_frame} to {stop_frame} ({stop_frame - start_frame + 1} frames)")
        print(f"      Duration: {duration:.2f} seconds at {frame_rate} FPS")
        
        # List animation layers
        num_layers = anim_stack.GetMemberCount(fbx.FbxCriteria.ObjectType(fbx.FbxAnimLayer.ClassId))
        print(f"      Layers: {num_layers}")


def traverse_hierarchy(node, scene, depth=0, show_transforms=False, show_animation=False):
    """Recursively traverse and print the node hierarchy."""
    indent = "  " * depth
    node_name = node.GetName()
    
    # Get attribute info
    attr_name, extra_info = get_node_attribute_info(node)
    
    # Get animation info if requested
    anim_info = ""
    if show_animation:
        anim_list = get_animation_info(node, scene)
        if anim_list:
            anim_info = f" [Anim: {','.join(anim_list)}]"
    
    # Get transform info if requested
    transform_info = ""
    if show_transforms:
        translation = node.LclTranslation.Get()
        rotation = node.LclRotation.Get()
        scaling = node.LclScaling.Get()
        transform_info = f"\n{indent}    T:({translation[0]:.2f}, {translation[1]:.2f}, {translation[2]:.2f})"
        transform_info += f" R:({rotation[0]:.2f}, {rotation[1]:.2f}, {rotation[2]:.2f})"
        transform_info += f" S:({scaling[0]:.2f}, {scaling[1]:.2f}, {scaling[2]:.2f})"
    
    print(f"{indent}{node_name} [{attr_name}]{extra_info}{anim_info}{transform_info}")
    
    # Traverse children
    for i in range(node.GetChildCount()):
        traverse_hierarchy(node.GetChild(i), scene, depth + 1, show_transforms, show_animation)


def get_scene_info(scene):
    """Get general scene information."""
    print("=== SCENE INFO ===")
    
    # Scene settings
    global_settings = scene.GetGlobalSettings()
    time_mode = global_settings.GetTimeMode()
    frame_rate = fbx.FbxTime.GetFrameRate(time_mode)
    
    print(f"Frame Rate: {frame_rate} FPS")
    print(f"Time Mode: {time_mode}")
    
    # Count different object types
    mesh_count = 0
    skeleton_count = 0
    camera_count = 0
    light_count = 0
    
    # Get attribute type constants dynamically
    def get_attr_constant(name):
        try:
            return getattr(fbx.FbxNodeAttribute.EType, name)
        except AttributeError:
            pass
        try:
            return getattr(fbx.FbxNodeAttribute, name)
        except AttributeError:
            pass
        return None
    
    mesh_type = get_attr_constant("eMesh")
    skeleton_type = get_attr_constant("eSkeleton")
    camera_type = get_attr_constant("eCamera")
    light_type = get_attr_constant("eLight")
    
    def count_nodes(node):
        nonlocal mesh_count, skeleton_count, camera_count, light_count
        
        node_attr = node.GetNodeAttribute()
        if node_attr:
            attr_type = node_attr.GetAttributeType()
            if mesh_type and attr_type == mesh_type:
                mesh_count += 1
            elif skeleton_type and attr_type == skeleton_type:
                skeleton_count += 1
            elif camera_type and attr_type == camera_type:
                camera_count += 1
            elif light_type and attr_type == light_type:
                light_count += 1
        
        for i in range(node.GetChildCount()):
            count_nodes(node.GetChild(i))
    
    count_nodes(scene.GetRootNode())
    
    print(f"Meshes: {mesh_count}")
    print(f"Skeleton Bones: {skeleton_count}")
    print(f"Cameras: {camera_count}")
    print(f"Lights: {light_count}")
    print(f"Materials: {scene.GetMaterialCount()}")
    print(f"Textures: {scene.GetTextureCount()}")


def main():
    if len(sys.argv) < 2:
        print("Usage: python fbx_list_structure.py <input.fbx> [options]")
        print("\nOptions:")
        print("  --transforms  - Show transform values (translation, rotation, scale)")
        print("  --animation   - Show which nodes have animation (T=translation, R=rotation, S=scale)")
        print("  --materials   - Show materials list")
        print("  --textures    - Show textures list")
        print("  --animations  - Show animation stacks info")
        print("  --all         - Show everything")
        return
    
    input_file = sys.argv[1]
    
    # Parse options
    show_transforms = "--transforms" in sys.argv or "--all" in sys.argv
    show_animation = "--animation" in sys.argv or "--all" in sys.argv
    show_materials = "--materials" in sys.argv or "--all" in sys.argv
    show_textures = "--textures" in sys.argv or "--all" in sys.argv
    show_animations = "--animations" in sys.argv or "--all" in sys.argv
    
    # Initialize FBX SDK
    manager, scene = FbxCommon.InitializeSdkObjects()
    
    # Load the FBX file
    print(f"Loading {input_file}...")
    result = FbxCommon.LoadScene(manager, scene, input_file)
    if not result:
        print(f"Failed to load {input_file}")
        manager.Destroy()
        return
    
    print("Scene loaded successfully\n")
    
    # Show scene info
    get_scene_info(scene)
    
    # Show animations if requested
    if show_animations:
        list_animations(scene)
    
    # Show materials if requested
    if show_materials:
        list_materials(scene)
    
    # Show textures if requested
    if show_textures:
        list_textures(scene)
    
    # Show hierarchy
    print("\n=== NODE HIERARCHY ===")
    root_node = scene.GetRootNode()
    traverse_hierarchy(root_node, scene, 0, show_transforms, show_animation)
    
    # Cleanup
    manager.Destroy()
    print(f"\nDone analyzing {input_file}")


if __name__ == "__main__":
    main()