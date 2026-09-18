from __future__ import annotations

import sys
sys.path.append(r"C:\Users\jango\Desktop\b_x_utils\py_modules")

from .parsing_funcs import *
from .zig_modules import x_mesh_zig
from .rdb.items import ItemDB,Item
from .rdb.chars import CharDB,Character

from ..panels import convenience_funcs as cf

from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from rfp import RFP
else:
    class RFP:
        pass

from . import b_funcs as bf

import bpy

import numpy as np
from math import pi

from dataclasses import dataclass,field

walls_list = ['null', '+WL', '+WR', '+DOB' , 'null', 'null', 'null', '+WC', 'null', 'null', 'null', '+WD', 'null', 'null', 'null', 'null']
wallthree = ['+WR', '+WL']
corners_list = ['null', '+CL', '+CR', '+CI', '+CO', 'null', 'unk', 'unk', 'floor?',  '+CL', '+CR', '+CI', '+CO', 'unk', 'unk', 'unk']
specials_list = ['unk','unk','unk','+TC','+TPP','+TNS','+TAW','+TEL','+TAL','+TAR','unk','unk','unk','unk','unk','unk']
turn = pi/2

enumed_specials_list = list(enumerate(specials_list))
wall_to_index_dict =   {string:i for i,string in enumerate(walls_list)}
corner_to_index_dict = {string:i for i,string in enumerate(corners_list)}

def get_tile_variant(obj: bpy.types.Object) -> int:
    var_start = bf.remove_duplicate_id(obj.name)[4:]
    return int(''.join([val for val in var_start if val.isnumeric()]))

@dataclass(slots = True)
class SortedTileset:
    name: str
    specials: dict[int,list[bpy.types.Object]] | None = field(default_factory = dict)
    walls:    dict[int,list[bpy.types.Object]] | None = field(default_factory = dict)
    corners:  dict[int,list[bpy.types.Object]] | None = field(default_factory = dict)
    floors:   dict[int,list[bpy.types.Object]] | None = field(default_factory = dict)
    @classmethod
    def sort(cls, name: str, objs: list[bpy.types.Object]) -> SortedTileset:
        print(f'\tSorting tileset {name} with {len(objs)} objects...')
        if 'ws' in name:
            specials = {i:{} for i,_ in enumerate(specials_list)}
            walls    = {i:{} for i,_ in enumerate(walls_list)}
            corners  = {i:{} for i,_ in enumerate(corners_list)}
            for obj in objs:
                obj['wallset'] = name
                if obj.name[1] != 'F':
                    variant = get_tile_variant(obj = obj)
                    if '+T' in obj.name: #I hate these things
                        for i,section in enumed_specials_list:
                            if section in obj.name:
                                specials[i][variant] = obj
                    elif obj.name[:3] in walls_list:   walls[wall_to_index_dict[obj.name[:3]] & 0b0111][variant] = obj
                    elif obj.name[:3] in corners_list: corners[corner_to_index_dict[obj.name[:3]] & 0b0111][variant] = obj
                    # else: #I hate these things
                    #     for i,name in enumerate(specials_list):
                    #         if name in obj.name[:3]:
                    #             specials[i][variant] = obj
            return SortedTileset(name = name,
                                 specials = specials,
                                 walls = walls,
                                 corners = corners)
        elif 'fs' in name:
            floors = {}
            for obj in objs:
                # obj.floorset = name
                if 'FMA' in obj.name:
                    variant = get_tile_variant(obj = obj) 
                    floors[variant] = obj
            return SortedTileset(name = name,
                                 floors = floors)
        else: raise Exception(f'Was provided a set with an unknown format: {name}')
    def get_wall(self, comp_index: int, var_index: int, col: bpy.types.Collection) -> bpy.types.Object:
        section = self.walls.get(comp_index & 0b0111)
        #If it cant get the variant, return the zeroth entry in the section.
        if section:
            return bf.copy_objects([section.get(var_index,section[list(section.keys())[0]])],col)[0]
    def get_corner(self, comp_index: int, var_index: int, col: bpy.types.Collection) -> bpy.types.Object:
        section = self.corners.get(comp_index & 0b0111)
        #If it cant get the variant, return the zeroth entry in the section.
        if section:
            return bf.copy_objects([section.get(var_index,section[list(section.keys())[0]])],col)[0]
    def get_special(self, comp_index: int, var_index: int, col: bpy.types.Collection) -> bpy.types.Object:
        section = self.specials[comp_index]
        if section:
            return bf.copy_objects([section.get(var_index,section[list(section.keys())[0]])],col)[0]
    def get_floor(self, var_index: int, col: bpy.types.Collection) -> bpy.types.Object:
        floors = self.floors
        return bf.copy_objects([floors.get(var_index, floors[list(floors.keys())[0]])],col)[0]

def get_nibbles_from_bytes(data: bytes) -> list[int]:
    return [n for b in data for n in (b >> 4, b & 0b1111)]

def build_terrain_sector(rft, pos_x: int, pos_y: int, col: bpy.types.Collection, mat: bpy.types.Material, built_brushes: list[str]) -> bpy.types.Object:
    tmesh = bpy.data.meshes.new(f'Terrain-{pos_x}-{pos_y}')
    verts,faces,brushes,holemap = rft.get_sector(pos_x,pos_y)
    # print(holemap)
    tmesh.from_pydata(verts,[],faces)
    for name,weights in brushes:
        if name not in built_brushes: 
            # print(f'Brush ({repr(name)}) is not in the built brushes: {built_brushes}')
            continue
        attr = tmesh.attributes.new(name, 'FLOAT', 'POINT')
        attr.data.foreach_set("value", weights)
    holemap_attr = tmesh.attributes.new('Holemap','INT','POINT')
    holemap_attr.data.foreach_set('value',holemap)
    tmesh.materials.append(mat)
    obj = bf.create_object(name = f'Terrain-{pos_x}-{pos_y}',data = tmesh)
    col.objects.link(obj)
    return obj

def parse_tilemap(rfp: RFP, name: str, file: BufferedReader, scene: bpy.types.Scene, import_settings: dict[str,bool], length: int, *args, **kwargs) -> tuple[str,None]:
    if not import_settings['import_sectors']: 
        file.seek(file.tell() + length)
        return 'Tiles',None 
    col = bf.verify_colname_in_scene(scene, 'Sectors')
    t_col = bf.verify_colname_in_scene(scene,'Terrain')
    print(f'Getting tilesets...')
    wallsets:  list[SortedTileset] = [rfp.get_set(read_name(file) + '.rfc') for i in range(read_uints(file,1))]
    floorsets: list[SortedTileset] = [rfp.get_set(read_name(file) + '.rfc') for i in range(read_uints(file,1))]
    dim_x,dim_y,null,scale = read_uints(file,4)
    tiles_n = dim_x*dim_y
    print(f'Reading tilemap array @ {hex(file.tell())}')
    nibbles_list = list(zip([get_nibbles_from_bytes(file.read(4)) for _ in range(tiles_n)], #Parts, vars, sets
                            [get_nibbles_from_bytes(file.read(4)) for _ in range(tiles_n)],
                            [get_nibbles_from_bytes(file.read(4)) for _ in range(tiles_n)]))
    tiles_arr = np.array([n for tile in nibbles_list for group in tile for n in group], dtype = np.uint8).reshape(dim_y,dim_x,3,8)

    x_start = -(scale * ((dim_x/2)) - scale/2)
    y_start = -(scale * ((dim_y/2)) - scale/2)
    print(f"Building sector map with size {hex(dim_y)}*{hex(dim_x)}")
    built_tiles_count = 0
    placed_objs = 0
    scene.exanima_brushes.clear()
    rft = rfp.resource.parse_entry(name = name.replace('.rfc','') + '.rft')
    print(rft.material)
    ftb = rfp.resource.parse_entry(f"{rft.material.lower()}.ftb", rfp)
    rft_found_brushes = rft.get_brushes()
    mat,built_brushes = ftb.build_brushes(rfp, rft_found_brushes)
    # mat,built_brushes = ftb.build_brushes(rfp, list(ftb.brush_dict.keys()) + list(ftb.mixed_brush_dict.keys()))
    for name in built_brushes: scene.exanima_brushes.add().name = name
    for y in range(dim_y):
        pos_y = y_start + y*scale
        for x in range(dim_x):
            pos_x = x_start + x*scale
            tile = tiles_arr[y,x]
            if tile[0,4] & 0b1000 and (tobj := build_terrain_sector(rft, x, y, t_col, mat, built_brushes)): tobj.location = pos_x,pos_y,0
            if not tile[0,5] & 0b1000: continue
            if tile[2,1] != 15: #Walls
                wallset = wallsets[tile[2,1]]
                for i,(comp,var) in enumerate(zip(tile[0,:4],tile[1,:4]),-1):
                    if not comp: continue
                    obj = wallset.get_wall(comp, var, col)
                    if obj:
                        obj.location = pos_x,pos_y,0
                        obj.rotation_euler.z = turn*i
                    else:
                        raise Exception(f'Failed to get object {(comp,var)} from {wallset.name} because it tried to access the following: {wallset.walls[comp]} in {wallset}')
                for i,(comp,var) in enumerate(zip(tile[0,4:],tile[1,4:]),-1):
                    if not comp: continue
                    obj = wallset.get_corner(comp, var, col)
                    if obj:
                        obj.location = pos_x,pos_y,0
                        obj.rotation_euler.z = turn*i
                if group := tile[2,5]: #Specials. I HATE THESE THINGS
                    orientation, modifier = tile[2,4],tile[2,7]
                    obj = wallset.get_special(comp_index = group, var_index = orientation%2 + modifier*2, col = col) 
                    if obj:
                        obj.location = pos_x,pos_y,0
                        obj.rotation_euler.z = turn * -(int(orientation)//2)
            if tile[2,0] != 15: #Floor
                floorset = floorsets[tile[2,0]]
                obj = floorset.get_floor(tile[2,3], col)
                if obj:
                    obj.location = pos_x,pos_y,0
                    obj.scale = 2,2,1
    return 'Tiles',None

def build_material(rfp: RFP, file: BufferedReader): #Will return bpy.types.Material 

    signature, length = read_uints(file,2)
    return file.read(length)

def parse_materials(rfp: RFP, file: BufferedReader, *args, **kwargs) -> tuple[str,list[bytes]]:
    return 'Materials',[build_material(rfp, file) for _ in range(read_uints(file,1))]

def build_node(rfp: RFP, file: BufferedReader, rfc_sig: int, col: bpy.types.Collection, nodes: list[bpy.types.Object], is_prop: bool = False) -> bpy.types.Object:
    node_type,length = read_uints(file,2)
    start = file.tell()
    name = read_name(file)
    # print(F"Reading node {name}")
    flags,objflag,suppress,parent = read_uints(file,4)
    tmatrix = read_x_tmatrix(file)
    bbox_scale = read_3dfvec(file) 
    bbox_pos   = read_3dfvec(file)
    if rfc_sig == 0x3D23AFCF: float_a,objint = unpack('<f L', file.read(8)) #0x74 bytes long
    else: objint,float_a = read_uints(file,1),0 #0x70 Bytes long;
    # print(f'Reading node data @ {hex(file.tell())} in {file.name}')
    file_data = file.read(length - (file.tell() - start))
    if suppress: data = nodes[suppress-1].data
    elif node_type == 0x3D03: #Mesh
        (vertices,
        face_vert_indices,
        loop_uvs,
        material_indices,
        material_names,
        faceints,
        faceflags,) = x_mesh_zig.parse_mesh(file_data, is_prop)
        mesh = bpy.data.meshes.new(name)
        
        mesh.from_pydata(vertices,[],face_vert_indices)
        
        uv_layer = mesh.uv_layers.new()
        # print(loop_uvs)
        uv_layer.data.foreach_set('uv',loop_uvs)

        if not is_prop:
            fi_attr = mesh.attributes.new(name="faceints", type='INT',domain='FACE')
            fi_attr.data.foreach_set("value", faceints)
            
            ff_attr = mesh.attributes.new(name="faceflags", type='STRING',domain='FACE')
            for ff,val in zip(ff_attr.data,faceflags):
                ff.value = hex(val).encode('ascii')
            # ff_attr.data.foreach_set("value", faceflags)
        
        for matname in material_names:
            mesh.materials.append(bpy.data.materials.get(matname) or bpy.data.materials.new(matname)) #Temp, created new ones if they dont exist. They will be created for realsies elsewhere 
        mesh.polygons.foreach_set("material_index",material_indices)
        data = mesh
    else: 
        data = None
    obj = bpy.data.objects.new(name,data)
    if parent: obj.parent = nodes[parent-1]
    obj.matrix_basis = tmatrix
    if col: col.objects.link(obj)
    return obj
    
def parse_nodes(rfp: RFP, file: BufferedReader, rfc_sig: int, scene: bpy.types.Scene, is_prop: bool = False, *args, **kwargs) -> tuple[str,list[bpy.types.Object]]:
    col = bf.verify_colname_in_scene(scene, 'Nodes') if scene else None
    nodes = []
    for i in range(read_uints(file,1)):
        obj = build_node(rfp, file, rfc_sig, col, nodes, is_prop)
        obj.node_index = i
        nodes.append(obj)
    root = nodes[0]
    for node in nodes:
        if node is root: continue
        node.root_node = root
    return 'Nodes',nodes

def parse_subnodev1(file: BufferedReader, objs_by_name: dict[str, bpy.types.Object], parent: bpy.types.Object | None = None) -> None:
    index, obj = read_uints(file,1), objs_by_name[read_name(file)]
    file.read(4) # Null
    obj.matrix_world = read_x_tmatrix(file)
    if parent: obj.parent = parent
    for _ in range(read_uints(file,1)): parse_subnodev1(file, objs_by_name, obj)

def parse_subnodesv1(file: BufferedReader, objs_by_name: dict[str, bpy.types.Object]) -> None:
    length, start = read_uints(file,1), file.tell()
    for _ in range(read_uints(file,1)): parse_subnodev1(file, objs_by_name)
    file.read(4) # Null

def parse_subnodev2(file: BufferedReader, objs_by_name: dict[str, bpy.types.Object], recursion: int = 0, parent: bpy.types.Object | None = None) -> None:
    if recursion and (signature := read_uints(file,1)) != 0x3DE0ECAC: 
        raise Exception(f'Signature ({hex(signature)}) is not a SubNodeV2 @ {hex(file.tell()-8)}')
    length, start = read_uints(file,1), file.tell()
    obj = objs_by_name.get(read_name(file))
    flag = read_uints(file,1) #??
    if obj: obj.matrix_world = read_x_tmatrix(file)
    else:   file.read(48)
    if parent and obj: obj.parent = parent
    children = []
    while file.tell() - start < length:
        children.append(parse_subnodev2(file, objs_by_name, recursion + 1, obj))

def parse_subnodes(file: BufferedReader, start: int, length: int, objs: list[bpy.types.Object]) -> None:
    objs_by_name = {bf.remove_duplicate_id(obj.name): obj for obj in objs}
    while file.tell() - start < length:
        signature = read_uints(file,1)
        if signature == 0x3DE0EC00: #V1
            parse_subnodesv1(file, objs_by_name)
        elif signature == 0x3DE0ECAC: #V2
            parse_subnodev2(file, objs_by_name)
        elif signature == 0x3DE0ECDB: #Softbody, unimplemented for now
            file.read(read_uints(file,1))
        else: raise Exception(f'Found an unknown subnode type ({hex(signature)}) @ {hex(file.tell())} in {file.name}. Started @ {hex(start)}')

def parse_props(rfp: RFP, file: BufferedReader, scene: bpy.types.Scene, length: int, import_settings: dict[str,bool], *args, **kwargs) -> tuple[str,None]:
    if not import_settings['import_props']: 
        file.seek(file.tell() + length)
        return 'Props', None
    if not scene: 
        print(f'RFC was not provided a destination scene. Skipping props.')
        file.seek(file.tell() + length)
        return 'Props', None
    col = bf.verify_colname_in_scene(scene, 'Props')
    props_n = read_uints(file,1)
    info_interval = props_n//5
    print(f"Building {hex(props_n)} props...")
    for i in range(props_n):
        if i%info_interval == 0: print(f'\tBuilding prop {hex(i + 1)} of {hex(props_n)}')
        signature,length = read_uints(file,2)
        if signature != 0x3DE10100: raise Exception(f"Found an incorrect prop ({hex(signature)}) @ {hex(file.tell())}")
        start = file.tell()
        flag = read_uints(file,1)
        objs = rfp.get_prop(read_name(file), col)
        objs[0].matrix_world = read_x_tmatrix(file)
        file.read(8) #null
        parse_subnodes(file, start, length, objs)
    return 'Props', None

def parse_itemdb(rfp: RFP, itemdb: ItemDB, itemdb_dict: dict[int,ItemDB], length: int, scene: bpy.types.Scene, import_settings: dict[str,bool], *args, **kwargs) -> tuple[str,ItemDB]:
    itemdb.parse_local_db(length, itemdb_dict)
    if not import_settings['import_items']:
        return 'ItemDB',itemdb
    col = bf.verify_colname_in_scene(scene, 'Items')
    #Since this is using x_utils, it has all of this already parsed in memory; in the ItemDB.
    items_n = len(itemdb.placed_items)
    info_interval = items_n//5
    print(f'Building {hex(items_n)} placed items...')
    for i,pitem in enumerate(itemdb.placed_items):
        if i%info_interval == 0: print(f'\tBuilding item {hex(i + 1)} of {hex(items_n)}')
        objs = pitem.item.to_objs(rfp, col)
        objs[0].matrix_world = pitem.tmatrix
        objs_by_name = {bf.remove_duplicate_id(obj.name): obj for obj in objs}
        for sn in pitem.subnodes:
            sn.pose(objs_by_name)
    return 'ItemDB',itemdb

def parse_chardb(rfp: RFP, chardb: CharDB, version: int, chardb_dict: dict[int,CharDB], itemdb_dict: dict[int,ItemDB], length: int, scene: bpy.types.Scene, import_settings: dict[str,bool], *args, **kwargs) -> tuple[str,CharDB]:
    # if not import_settings['import_chars']:
    #     return 'CharDB',chardb
    chardb.parse_local_db(length = length, version = version, chardb_dict = chardb_dict, itemdb_dict = itemdb_dict)
    if not import_settings['import_chars']:
        return 'CharDB',chardb
    col = bf.verify_colname_in_scene(scene,'Chars')
    chars_n = len(chardb.placed_chars)
    info_interval = chars_n // 5
    print(f'Building {hex(chars_n)} placed characters...')
    for i,pchar in enumerate(chardb.placed_chars):
        if i%info_interval == 0: print(f'\tBuilding char {hex(i + 1)} of {hex(chars_n)}')
        char: Character = pchar.char
        if not char: continue
        objs = char.to_objs(rfp, col)
        obj = objs[0]
        obj.location += pchar.pos.xzy
        obj.rotation_euler.z = pchar.rot
        obj.x_char.state = pchar.state
        if pchar.pose:
            if pchar.pose_sig == 0xCAC0E100:
                for bone,tmatrix in zip(objs,pchar.pose[:len(objs)]): #Lop off anything extra
                    bone.matrix_world = tmatrix
            elif pchar.pose_sig == 0xCAC0EB00:
                bone_dict = {}
                for i,obj in enumerate(objs):
                    if obj.name[:2].isnumeric(): bone_dict[int(obj.name[:2])] = obj
                    else:                        bone_dict[i + 2] = obj
                pchar.pose.pose(bone_dict)
        #It appears the nodes can be out of sequence. Search for the root object.
        cf.get_root_in_hierarchy(obj).name = char.name
    return 'CharDB',chardb

rfc_chunk_dict = {
    0x00003DED: parse_tilemap,
    0x0000BA00: parse_materials,
    0x3D000000: parse_nodes,
    0x3DE10000: parse_props,
    0x0000DBC0: parse_itemdb,
    0xCAC00000: parse_chardb,
    0xCAC00001: parse_chardb
}

def parse_rfc(rfp: RFP, name: str, file: BufferedReader, size: int, scene: bpy.types.Scene | None, 
              import_settings: dict[str,bool] = {'import_sectors': True,'import_props': True},
              read_signature: bool = True, signature: int = 0x3D23AFCF, return_nodes: bool = True,
              is_prop: bool = False,
              itemdb_dict: dict[int,ItemDB] = {}, chardb_dict: dict[int,CharDB] = {}):
    if read_signature:
        start = file.tell()
        signature = read_uints(file,1)
    else: start = file.tell() - 4
    if not is_prop:
        itemdb = ItemDB(file = file, name = name, signature = 0x80000000) #local/level db
        itemdb_dict[0x80000000] = itemdb
        localedb = rfp.locales
        chardb = CharDB(file = file, locale_id = localedb.get_locale_by_name(name, return_id = True), db_dict = itemdb_dict, rfp = rfp, name = name)
        chardb_dict[0x80000000] = chardb
    else: itemdb,chardb = None,None
    chunks = {}
    while file.tell() - start < size:
        chunk_signature,chunk_length = read_uints(file,2)
        func = rfc_chunk_dict.get(chunk_signature)
        chunk_type,data = func(rfp = rfp, name = name, file = file, signature = signature, rfc_sig = signature, 
                               scene = scene, length = chunk_length, import_settings = import_settings, 
                               is_prop = is_prop, 
                               itemdb = itemdb, itemdb_dict = itemdb_dict,
                               chardb = chardb, chardb_dict = chardb_dict, 
                               version = chunk_signature) if func else (hex(chunk_signature),file.read(chunk_length))
        chunks[chunk_type] = data
    return chunks['Nodes'] if return_nodes else chunks