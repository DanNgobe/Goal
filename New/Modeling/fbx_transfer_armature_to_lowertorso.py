"""
fbx_transfer_armature_to_lowertorso.py

The problem:
  The Armature (Null) node has all 72 keys of translation + rotation animation.
  LowerTorso has zero animation (just 1 rest-pose key).
  Roblox ignores the Armature node so LowerTorso stays frozen.

The fix:
  1. Copy all translation keys from Armature -> LowerTorso
     - Divide values by 100 (Armature scale=100, bones are scale=1)
     - Subtract the static Y offset (0.2664) so it starts at 0
  2. Copy all rotation keys from Armature -> LowerTorso
     - Rotation is scale-independent, transfer as-is
  3. Remove the Armature node and reparent Root directly under RootNode
     (so Roblox doesn't get confused by the Null node)
"""

import fbx
import FbxCommon
import sys


def get_anim_stack(scene):
    n = scene.GetSrcObjectCount(fbx.FbxCriteria.ObjectType(fbx.FbxAnimStack.ClassId))
    return scene.GetSrcObject(fbx.FbxCriteria.ObjectType(fbx.FbxAnimStack.ClassId), 0) if n > 0 else None


def get_anim_layer(stack):
    return stack.GetMember(fbx.FbxCriteria.ObjectType(fbx.FbxAnimLayer.ClassId), 0)


def find_node(root, name):
    if root.GetName() == name:
        return root
    for i in range(root.GetChildCount()):
        r = find_node(root.GetChild(i), name)
        if r:
            return r
    return None


def read_curve(curve):
    """Read all keys from a curve as list of (FbxTime, float)."""
    if not curve:
        return []
    return [(curve.KeyGetTime(k), curve.KeyGetValue(k)) for k in range(curve.KeyGetCount())]


def write_curve(node_property, anim_layer, axis, keys, create=True):
    """Write keys to a curve, creating it if needed."""
    curve = node_property.GetCurve(anim_layer, axis, create)
    if not curve:
        print(f"  WARNING: Could not get/create curve for axis {axis}")
        return

    curve.KeyClear()
    curve.KeyModifyBegin()
    for time, value in keys:
        idx, _ = curve.KeyAdd(time)
        curve.KeySetValue(idx, value)
        curve.KeySetInterpolation(idx, fbx.FbxAnimCurveDef.EInterpolationType.eInterpolationLinear)
    curve.KeyModifyEnd()


def main():
    skip_scale = "--skip-scale" in sys.argv
    if skip_scale:
        sys.argv.remove("--skip-scale")

    if len(sys.argv) < 3:
        print("Usage: py -3.10 fbx_transfer_armature_to_lowertorso.py <input.fbx> <output.fbx> [--skip-scale]")
        print()
        print("Transfers animation from the Armature null node onto LowerTorso")
        print("so Roblox retargeting can correctly drive the character.")
        return

    input_file  = sys.argv[1]
    output_file = sys.argv[2]

    manager, scene = FbxCommon.InitializeSdkObjects()

    print(f"Loading {input_file} ...")
    if not FbxCommon.LoadScene(manager, scene, input_file):
        print("Failed to load.")
        manager.Destroy()
        return

    scene_root = scene.GetRootNode()

    anim_stack = get_anim_stack(scene)
    if not anim_stack:
        print("No animation found.")
        manager.Destroy()
        return

    scene.SetCurrentAnimationStack(anim_stack)
    anim_layer = get_anim_layer(anim_stack)
    time_mode  = scene.GetGlobalSettings().GetTimeMode()

    # -----------------------------------------------------------------------
    # Find nodes
    # -----------------------------------------------------------------------
    armature    = find_node(scene_root, "Armature")
    lower_torso = find_node(scene_root, "LowerTorso")
    root_bone   = find_node(scene_root, "Root")

    if not armature:
        print("ERROR: Could not find Armature node.")
        manager.Destroy()
        return

    if not lower_torso:
        print("ERROR: Could not find LowerTorso bone.")
        manager.Destroy()
        return

    print(f"Found Armature: {armature.GetName()}")
    print(f"Found LowerTorso: {lower_torso.GetName()}")

    # -----------------------------------------------------------------------
    # Read Armature scale (should be 100)
    # -----------------------------------------------------------------------
    arm_scale = armature.LclScaling.Get()
    scale_x   = arm_scale[0]
    scale_y   = arm_scale[1]
    scale_z   = arm_scale[2]
    print(f"\nArmature scale: {scale_x}, {scale_y}, {scale_z}")

    # Static Y offset baked into Armature translation
    arm_static_t = armature.LclTranslation.Get()
    static_y_offset = arm_static_t[1]
    print(f"Armature static Y offset: {static_y_offset:.4f}")

    # -----------------------------------------------------------------------
    # Read all translation keys from Armature
    # -----------------------------------------------------------------------
    arm_tx = read_curve(armature.LclTranslation.GetCurve(anim_layer, "X"))
    arm_ty = read_curve(armature.LclTranslation.GetCurve(anim_layer, "Y"))
    arm_tz = read_curve(armature.LclTranslation.GetCurve(anim_layer, "Z"))

    print(f"\nArmature translation keys: X={len(arm_tx)} Y={len(arm_ty)} Z={len(arm_tz)}")

    # -----------------------------------------------------------------------
    # Read all rotation keys from Armature
    # -----------------------------------------------------------------------
    arm_rx = read_curve(armature.LclRotation.GetCurve(anim_layer, "X"))
    arm_ry = read_curve(armature.LclRotation.GetCurve(anim_layer, "Y"))
    arm_rz = read_curve(armature.LclRotation.GetCurve(anim_layer, "Z"))

    print(f"Armature rotation keys:    X={len(arm_rx)} Y={len(arm_ry)} Z={len(arm_rz)}")

    # -----------------------------------------------------------------------
    # Scale down translation values (divide by armature scale)
    # and subtract the static Y offset so character starts at origin
    # -----------------------------------------------------------------------
    def scale_t(keys, divisor, subtract=0.0):
        if skip_scale:
            divisor = 1.0
        return [(t, (v - subtract) / divisor) for t, v in keys]

    new_tx = scale_t(arm_tx, scale_x)
    new_ty = scale_t(arm_ty, scale_y, subtract=static_y_offset)
    new_tz = scale_t(arm_tz, scale_z)

    # Sample to verify
    if new_tx:
        print(f"\nTransferred T.X first 3: {[round(v,4) for _,v in new_tx[:3]]}")
    if new_ty:
        print(f"Transferred T.Y first 3: {[round(v,4) for _,v in new_ty[:3]]}")
    if new_tz:
        print(f"Transferred T.Z first 3: {[round(v,4) for _,v in new_tz[:3]]}")

    # -----------------------------------------------------------------------
    # Write translation keys onto LowerTorso
    # -----------------------------------------------------------------------
    print("\nWriting translation keys to LowerTorso...")
    if new_tx:
        write_curve(lower_torso.LclTranslation, anim_layer, "X", new_tx)
        print(f"  Wrote {len(new_tx)} keys to T.X")
    if new_ty:
        write_curve(lower_torso.LclTranslation, anim_layer, "Y", new_ty)
        print(f"  Wrote {len(new_ty)} keys to T.Y")
    if new_tz:
        write_curve(lower_torso.LclTranslation, anim_layer, "Z", new_tz)
        print(f"  Wrote {len(new_tz)} keys to T.Z")

    # -----------------------------------------------------------------------
    # Write rotation keys onto LowerTorso
    # (rotation is scale-independent, transfer as-is)
    # -----------------------------------------------------------------------
    print("\nWriting rotation keys to LowerTorso...")
    if arm_rx:
        write_curve(lower_torso.LclRotation, anim_layer, "X", arm_rx)
        print(f"  Wrote {len(arm_rx)} keys to R.X")
    if arm_ry:
        write_curve(lower_torso.LclRotation, anim_layer, "Y", arm_ry)
        print(f"  Wrote {len(arm_ry)} keys to R.Y")
    if arm_rz:
        write_curve(lower_torso.LclRotation, anim_layer, "Z", arm_rz)
        print(f"  Wrote {len(arm_rz)} keys to R.Z")

    # -----------------------------------------------------------------------
    # Remove Armature and reparent Root directly under scene root
    # -----------------------------------------------------------------------
    print("\nRemoving Armature node...")
    if root_bone and armature:
        armature.RemoveChild(root_bone)
        scene_root.AddChild(root_bone)
        scene_root.RemoveChild(armature)
        print(f"  Reparented Root directly under RootNode")
        print(f"  Removed Armature")

    # -----------------------------------------------------------------------
    # Set LowerTorso static translation to 0 (clean rest pose)
    # -----------------------------------------------------------------------
    lower_torso.LclTranslation.Set(fbx.FbxDouble3(0.0, 0.0, 0.0))

    # -----------------------------------------------------------------------
    # Save
    # -----------------------------------------------------------------------
    print(f"\nSaving to {output_file} ...")
    if FbxCommon.SaveScene(manager, scene, output_file):
        print("Done!")
        print("LowerTorso now has full translation + rotation animation.")
        print("Import into Roblox Studio and test.")
    else:
        print("Failed to save.")

    manager.Destroy()


if __name__ == "__main__":
    main()
