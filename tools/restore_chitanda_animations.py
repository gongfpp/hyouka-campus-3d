#!/usr/bin/env python3
"""Restore released Chitanda animation streams onto a preserved visual candidate.

The candidate's existing JSON, bufferViews, accessors and BIN prefix are preserved
except for animations and the required buffer byteLength. Source animation
bufferViews/accessors are appended without resampling. No third-party packages.

Reproduce from the project root (use the preserved pre-restore candidate):
  python tools/restore_chitanda_animations.py \
    --baseline ../chitanda-game-baseline/assets/characters/chitanda.glb \
    --candidate artifacts/chitanda-integration/candidate-before-animation-restore.glb \
    --output assets/characters/chitanda.glb \
    --report artifacts/chitanda-integration/animation-restore-report.json
"""

import argparse
import copy
import hashlib
import json
import math
from pathlib import Path
import struct


JSON_CHUNK = 0x4E4F534A
BIN_CHUNK = 0x004E4942
FORMATS = {5120: "b", 5121: "B", 5122: "h", 5123: "H", 5125: "I", 5126: "f"}
WIDTHS = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}
EXPECTED_ANIMATIONS = {"idle", "walk", "run"}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def canonical(data):
    return json.dumps(data, sort_keys=True, separators=(",", ":")).encode()


def read_glb(path):
    data = path.read_bytes()
    require(len(data) >= 20, "Truncated GLB")
    magic, version, length = struct.unpack_from("<III", data)
    require(magic == 0x46546C67 and version == 2 and length == len(data), "Invalid GLB v2 header")
    chunks = []
    position = 12
    while position < len(data):
        size, kind = struct.unpack_from("<II", data, position)
        payload = data[position + 8:position + 8 + size]
        require(len(payload) == size and size % 4 == 0, "Invalid GLB chunk")
        chunks.append((kind, payload))
        position += 8 + size
    require([kind for kind, _ in chunks] == [JSON_CHUNK, BIN_CHUNK], "Expected JSON and BIN chunks only")
    document = json.loads(chunks[0][1])
    binary = chunks[1][1]
    require(len(document.get("buffers", [])) == 1 and "uri" not in document["buffers"][0], "Expected one embedded buffer")
    require(document["buffers"][0]["byteLength"] <= len(binary), "Invalid embedded buffer length")
    return document, binary, data


def accessor(document, binary, index):
    value = document["accessors"][index]
    require(not value.get("sparse"), "Sparse accessors are intentionally unsupported")
    view = document["bufferViews"][value["bufferView"]]
    require(view.get("buffer", 0) == 0, "Expected buffer 0")
    require(value["type"] in WIDTHS and value["componentType"] in FORMATS, "Unsupported accessor encoding")
    fmt = "<" + FORMATS[value["componentType"]] * WIDTHS[value["type"]]
    size = struct.calcsize(fmt)
    stride = view.get("byteStride", size)
    start = view.get("byteOffset", 0) + value.get("byteOffset", 0)
    require(stride >= size, "Invalid accessor stride")
    end = start + max(0, value["count"] - 1) * stride + size
    require(end <= view.get("byteOffset", 0) + view["byteLength"], "Accessor exceeds bufferView")
    raw = b"".join(binary[start + k * stride:start + k * stride + size] for k in range(value["count"]))
    require(len(raw) == size * value["count"], "Truncated accessor")
    return raw, list(struct.iter_unpack(fmt, raw))


def names(document):
    result = {}
    for index, node in enumerate(document["nodes"]):
        name = node.get("name")
        require(name and name not in result, "Every node name must be present and unique")
        result[name] = index
    return result


def distance(left, right):
    return math.sqrt(sum((a - b) ** 2 for a, b in zip(left, right)))


def angle(left, right):
    norm = math.sqrt(sum(x * x for x in left) * sum(x * x for x in right))
    require(norm > 0, "Invalid zero quaternion")
    dot = min(1.0, abs(sum(a * b for a, b in zip(left, right))) / norm)
    return math.degrees(2 * math.acos(dot))


def check_rig(source, source_binary, target, target_binary):
    require(len(source.get("skins", [])) == len(target.get("skins", [])) == 1, "Expected exactly one skin")
    old_skin, new_skin = source["skins"][0], target["skins"][0]
    old_joints, new_joints = old_skin["joints"], new_skin["joints"]
    require(len(old_joints) == len(new_joints) == 17, "Expected 17 joints")
    old_names = [source["nodes"][i]["name"] for i in old_joints]
    new_names = [target["nodes"][i]["name"] for i in new_joints]
    require(old_names == new_names, "Joint names/order differ")
    thresholds = {"translation": 5e-6, "rotation_degrees": 0.001, "scale": 5e-6, "inverse_bind_component": 5e-6}
    rows = []
    for old_index, new_index in zip(old_joints, new_joints):
        old, new = source["nodes"][old_index], target["nodes"][new_index]
        require("matrix" not in old and "matrix" not in new, "Matrix-form nodes are intentionally unsupported")
        old_children = [source["nodes"][i]["name"] for i in old.get("children", [])]
        new_children = [target["nodes"][i]["name"] for i in new.get("children", [])]
        require(old_children == new_children, "Bone child topology differs")
        row = {"bone": old["name"], "translation": distance(old.get("translation", [0, 0, 0]), new.get("translation", [0, 0, 0])), "rotation_degrees": angle(old.get("rotation", [0, 0, 0, 1]), new.get("rotation", [0, 0, 0, 1])), "scale": distance(old.get("scale", [1, 1, 1]), new.get("scale", [1, 1, 1]))}
        for key in ("translation", "rotation_degrees", "scale"):
            require(row[key] <= thresholds[key], "Bone rest difference exceeds threshold: " + old["name"] + " " + key)
        rows.append(row)
    _, old_ib = accessor(source, source_binary, old_skin["inverseBindMatrices"])
    _, new_ib = accessor(target, target_binary, new_skin["inverseBindMatrices"])
    require(len(old_ib) == len(new_ib) == 17, "Inverse bind matrix count differs")
    maximum = max(abs(a - b) for left, right in zip(old_ib, new_ib) for a, b in zip(left, right))
    require(maximum <= thresholds["inverse_bind_component"], "Inverse bind differences exceed threshold")
    old_parents = {child: index for index, node in enumerate(source["nodes"]) for child in node.get("children", [])}
    new_parents = {child: index for index, node in enumerate(target["nodes"]) for child in node.get("children", [])}
    for old_index, new_index in zip(old_joints, new_joints):
        if old_index in old_parents and old_parents[old_index] not in old_joints:
            require(new_index in new_parents, "Skeleton parent missing")
            old_parent = source["nodes"][old_parents[old_index]]
            new_parent = target["nodes"][new_parents[new_index]]
            for key in ("name", "translation", "rotation", "scale", "matrix"):
                require(old_parent.get(key) == new_parent.get(key), "Skeleton parent transform differs")
    return {"joint_count": 17, "joint_names": old_names, "thresholds": thresholds, "bone_differences": rows, "inverse_bind_max_component_delta": maximum}


def run(args):
    require(args.candidate.resolve() != args.output.resolve(), "Use the preserved candidate as input, not the output path")
    require(args.baseline.resolve() != args.output.resolve(), "Cannot overwrite baseline")
    source, source_binary, source_file = read_glb(args.baseline)
    before, before_binary, candidate_file = read_glb(args.candidate)
    source_names, target_names = names(source), names(before)
    rig = check_rig(source, source_binary, before, before_binary)
    animation_names = [a.get("name") for a in source.get("animations", [])]
    require(len(animation_names) == 3 and set(animation_names) == EXPECTED_ANIMATIONS, "Expected exactly idle, walk, run")
    after = copy.deepcopy(before)
    binary = bytearray(before_binary)
    views, accessors = {}, {}

    def copy_view(index):
        if index not in views:
            original = source["bufferViews"][index]
            require(original.get("buffer", 0) == 0, "Source view must use embedded buffer")
            offset, length = original.get("byteOffset", 0), original["byteLength"]
            payload = source_binary[offset:offset + length]
            require(len(payload) == length, "Truncated source view")
            binary.extend(b"\0" * (-len(binary) % 4))
            value = copy.deepcopy(original)
            value["buffer"], value["byteOffset"] = 0, len(binary)
            views[index] = len(after["bufferViews"])
            after["bufferViews"].append(value)
            binary.extend(payload)
        return views[index]

    def copy_accessor(index):
        if index not in accessors:
            accessor(source, source_binary, index)
            value = copy.deepcopy(source["accessors"][index])
            value["bufferView"] = copy_view(value["bufferView"])
            accessors[index] = len(after["accessors"])
            after["accessors"].append(value)
        return accessors[index]

    restored = []
    for animation in source["animations"]:
        value = copy.deepcopy(animation)
        for sampler in value["samplers"]:
            for key in ("input", "output"):
                sampler[key] = copy_accessor(sampler[key])
        seen = set()
        for channel in value["channels"]:
            original_index = channel["target"]["node"]
            name = source["nodes"][original_index]["name"]
            require(name in rig["joint_names"] and name in target_names, "Animation target is not a known bone")
            require(channel["target"]["path"] in ("translation", "rotation", "scale"), "Unexpected animation target path")
            key = (name, channel["target"]["path"])
            require(key not in seen, "Duplicate animation channel")
            seen.add(key)
            channel["target"]["node"] = target_names[name]
        require(len(seen) == 51, "Expected 51 bone TRS channels per animation")
        restored.append(value)
    after["animations"] = restored
    after["buffers"][0]["byteLength"] = len(binary)
    json_chunk = json.dumps(after, separators=(",", ":"), ensure_ascii=False).encode()
    json_chunk += b" " * (-len(json_chunk) % 4)
    binary.extend(b"\0" * (-len(binary) % 4))
    output = struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(json_chunk) + 8 + len(binary)) + struct.pack("<II", len(json_chunk), JSON_CHUNK) + json_chunk + struct.pack("<II", len(binary), BIN_CHUNK) + binary

    mutable = {"animations", "accessors", "bufferViews", "buffers"}
    immutable_before = {k: v for k, v in before.items() if k not in mutable}
    immutable_after = {k: v for k, v in after.items() if k not in mutable}
    require(immutable_before == immutable_after, "Non-animation JSON changed")
    require(after["accessors"][:len(before["accessors"]) ] == before["accessors"], "Existing accessors changed")
    require(after["bufferViews"][:len(before["bufferViews"]) ] == before["bufferViews"], "Existing bufferViews changed")
    require(binary[:len(before_binary)] == before_binary, "Existing binary prefix changed")
    old_buffer = copy.deepcopy(before["buffers"][0]); new_buffer = copy.deepcopy(after["buffers"][0])
    old_buffer.pop("byteLength"); new_buffer.pop("byteLength")
    require(old_buffer == new_buffer, "Other buffer metadata changed")

    channel_reports = []
    for old, new in zip(source["animations"], after["animations"]):
        for old_channel, new_channel in zip(old["channels"], new["channels"]):
            old_sampler = old["samplers"][old_channel["sampler"]]
            new_sampler = new["samplers"][new_channel["sampler"]]
            require(old_sampler.get("interpolation", "LINEAR") == new_sampler.get("interpolation", "LINEAR"), "Interpolation changed")
            name = source["nodes"][old_channel["target"]["node"]]["name"]
            require(after["nodes"][new_channel["target"]["node"]]["name"] == name, "Target mapping changed")
            row = {"animation": old["name"], "bone": name, "path": old_channel["target"]["path"], "interpolation": old_sampler.get("interpolation", "LINEAR")}
            for key in ("input", "output"):
                old_raw, old_values = accessor(source, source_binary, old_sampler[key])
                new_raw, new_values = accessor(after, binary, new_sampler[key])
                require(old_raw == new_raw and old_values == new_values, "Restored animation data mismatch")
                row[key] = {"source_accessor": old_sampler[key], "restored_accessor": new_sampler[key], "sha256": sha(new_raw), "value_count": len(new_values), "bytes_equal": True, "values_equal": True}
            channel_reports.append(row)

    report = {"status": "PASS", "method": "Append exact baseline animation bufferViews/accessors; map channel targets by unique bone name; no resampling", "baseline_sha256": sha(source_file), "candidate_before_sha256": sha(candidate_file), "output_sha256": sha(output), "candidate_bytes": len(candidate_file), "output_bytes": len(output), "rig_compatibility": rig, "immutable_json_sha256_before": sha(canonical(immutable_before)), "immutable_json_sha256_after": sha(canonical(immutable_after)), "existing_binary_prefix_sha256_before": sha(before_binary), "existing_binary_prefix_sha256_after": sha(binary[:len(before_binary)]), "existing_binary_prefix_bytes": len(before_binary), "existing_accessors_unchanged": True, "existing_bufferViews_unchanged": True, "meshes_materials_skins_nodes_images_textures_unchanged": True, "source_animation_names": animation_names, "restored_channels": len(channel_reports), "all_source_animation_inputs_outputs_exact": True, "appended_bufferViews": len(views), "appended_accessors": len(accessors), "channels": channel_reports, "limitations": ["Bone rest transforms and inverse binds are preserved from the visual candidate, with preflight differences below recorded thresholds.", "Runtime import, rendering and animation playability must be validated separately.", "The resulting GLB is an integration derivative; it no longer has the same file hash as the unmodified hairfix candidate."]}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    temporary = args.output.with_suffix(args.output.suffix + ".restore.tmp")
    require(not temporary.exists(), "Temporary output already exists")
    temporary.write_bytes(output)
    verified, verified_binary, verified_file = read_glb(temporary)
    require(verified == after and verified_binary == binary and sha(verified_file) == report["output_sha256"], "Written GLB verification failed")
    temporary.replace(args.output)
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({key: report[key] for key in ("status", "baseline_sha256", "candidate_before_sha256", "output_sha256", "restored_channels", "appended_bufferViews", "appended_accessors", "all_source_animation_inputs_outputs_exact")}, indent=2))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--baseline", required=True, type=Path)
    parser.add_argument("--candidate", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--report", required=True, type=Path)
    run(parser.parse_args())
