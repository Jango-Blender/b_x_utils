from __future__ import annotations

import bpy

from .parsing_funcs import *
# from parsing_funcs import *

from dataclasses import dataclass,field

from typing import TYPE_CHECKING
if TYPE_CHECKING:
    from rfp import RFP

@dataclass
class Brush:
    #v2 = 0xD8 bytes long
    #v3 = 0xE8 bytes long
    version: int = 0x3
    name:    str = ''
    unk1:    int = 0x0
    diffuse: str = '' #16s
    normal:  str = '' #16s
    gloss:   str = '' #16s
    m:       str = '' #16s, ?
    height:  str = '' #16s
    b:       str = '' #16s
    diffuse_color: tuple = (0.0,0.0,0.0,0.0) #4*f32
    normal_color:  tuple = (0.0,0.0,0.0,0.0) #4*f32
    gloss_color:   tuple = (0.0,0.0,0.0,0.0) #4*f32
    m_color:       tuple = (0.0,0.0,0.0,0.0) #4*f32
    height_color:  tuple = (0.0,0.0,0.0,0.0) #4*f32
    b_color:       tuple = (0.0,0.0,0.0,0.0) #4*f32
    unk_color:     tuple = (0.0,0.0,0.0,0.0) #4*f32
    unk2:   int = 0x0
    @classmethod
    def parse(cls, file: BufferedReader, version: int = 0x3) -> Brush:
        return Brush(version = version,
                     name = read_name(file).lower(),
                     unk1 = read_uints(file,1),
                     diffuse = read_name(file),
                     normal  = read_name(file),
                     gloss   = read_name(file),
                     m       = read_name(file),
                     height  = read_name(file),
                     b       = read_name(file),
                     diffuse_color = read_floats(file,4),
                     normal_color  = read_floats(file,4),
                     gloss_color   = read_floats(file,4),
                     m_color       = read_floats(file,4),
                     height_color  = read_floats(file,4),
                     b_color       = read_floats(file,4),
                     unk_color     = read_floats(file,4) if version == 0x3 else (0,0,0,0),
                     unk2 = read_uints(file,1))
    def build(self, rfp: RFP, node_tree: bpy.types.ShaderNodeTree | None, node_tree_dict: dict[str,bpy.types.ShaderNodeTree]) -> bpy.types.ShaderNodeTree | bpy.types.ShaderNode:
        if self.name in node_tree_dict: 
            group_tree = node_tree_dict.get(self.name)
            if node_tree:
                group_node = node_tree.nodes.new("ShaderNodeGroup")
                group_node.node_tree = group_tree
                return group_node
            else:
                return group_tree
        print(f'Building brush {self.name}...')
        
        group_tree = bpy.data.node_groups.new(self.name,'ShaderNodeTree')
        group_tree.interface.new_socket(name='Color', in_out='OUTPUT', socket_type='NodeSocketColor')

        node_tree_dict[self.name] = group_tree

        nodes,links = group_tree.nodes, group_tree.links

        texture_coord_node = nodes.new(type = 'ShaderNodeTexCoord')
        mapping_node = nodes.new(type = 'ShaderNodeMapping')
        mapping_node.vector_type = 'TEXTURE'
        links.new(texture_coord_node.outputs['Generated'], mapping_node.inputs['Vector'])

        d_img_node = nodes.new('ShaderNodeTexImage')
        d_img_node.image = rfp.get_image(self.diffuse.lower()) #no .rfi
        links.new(mapping_node.outputs['Vector'],d_img_node.inputs['Vector'])

        output_node = nodes.new('NodeGroupOutput')
        links.new(d_img_node.outputs['Color'],output_node.inputs['Color'])

        if node_tree:
            group_node = node_tree.nodes.new("ShaderNodeGroup")
            group_node.node_tree = group_tree
            return group_node
        else:
            return group_tree
    def __repr__(self):
        return f'Brush(name={self.name})'


@dataclass
class MixedBrush:
    #0x40 bytes long
    name: str = ''
    flag_1: int = 0
    flag_2: int = 0
    brush_a: Brush | MixedBrush | None = None
    brush_b: Brush | MixedBrush | None = None
    level_a: float = 0.0
    level_b: float = 0.0
    @classmethod
    def parse(cls, ftb: FTB, file: BufferedReader) -> Brush:
        name = read_name(file).lower()
        mb = ftb.mixed_brush_dict.setdefault(name,MixedBrush(name))
        mb.flag_1,mb.flag_2 = read_uints(file,2)
        mb.brush_a = ftb.get_brush(read_name(file).lower())
        mb.brush_b = ftb.get_brush(read_name(file).lower())
        mb.level_a,mb.level_b = read_floats(file,2)
        return mb
    def build(self, rfp: RFP, node_tree: bpy.types.ShaderNodeTree | None, node_tree_dict: dict[str,bpy.types.ShaderNodeTree]) -> bpy.types.ShaderNodeTree:
        if self.name in node_tree_dict: 
            group_tree = node_tree_dict.get(self.name)
            if node_tree:
                group_node = node_tree.nodes.new("ShaderNodeGroup")
                group_node.node_tree = group_tree
                return group_node
            else:
                return group_tree
        print(f'Building mixed brush {self.name}...')
        group_tree = bpy.data.node_groups.new(self.name,'ShaderNodeTree')
        group_tree.interface.new_socket('Color', socket_type = 'NodeSocketColor', in_out = 'OUTPUT')
        
        node_tree_dict[self.name] = group_tree
        
        nodes,links = group_tree.nodes,group_tree.links

        brush_a_node = group_tree.nodes.new("ShaderNodeGroup")
        brush_a_node.node_tree = self.brush_a.build(rfp, None, node_tree_dict)
        brush_b_node = group_tree.nodes.new("ShaderNodeGroup")
        brush_b_node.node_tree = self.brush_b.build(rfp, None, node_tree_dict)
        
        

        mix_node = nodes.new(type = 'ShaderNodeMix')
        mix_node.data_type = 'RGBA'
        mix_node.inputs[0].default_value = (self.level_a - self.level_b) / (self.level_a + self.level_b) #self.level_a / (self.level_a + self.level_b)
        mix_node.inputs[6].default_value = (0.0,0.0,0.0,1.0)
        mix_node.inputs[7].default_value = (0.0,0.0,0.0,1.0)
        links.new(brush_a_node.outputs['Color'],mix_node.inputs['B'])
        links.new(brush_b_node.outputs['Color'],mix_node.inputs['A'])

        output_node = nodes.new('NodeGroupOutput')
        links.new(mix_node.outputs['Result'],output_node.inputs['Color'])

        if node_tree:
            group_node = node_tree.nodes.new("ShaderNodeGroup")
            group_node.node_tree = group_tree
            return group_node
        else:
            return group_tree
    def __repr__(self):
        return f'MixedBrush(name={self.name}, brush_a={self.brush_a}, brush_b={self.brush_b}, flag_1={hex(self.flag_1)}, flag_2={hex(self.flag_2)}, level_a={self.level_a}, level_b={self.level_b})'

@dataclass
class Details:
    #0x68 bytes long
    unk1: int = 0x1
    name: str = ''
    color_0: tuple = (0.0,0.0,0.0,0.0)
    color_1: tuple = (0.0,0.0,0.0,0.0)
    color_2: tuple = (0.0,0.0,0.0,0.0)
    color_3: tuple = (0.0,0.0,0.0,0.0)
    color_4: tuple = (0.0,0.0,0.0,0.0)
    unk2: int = 0x0
    @classmethod
    def parse(cls, file: BufferedReader) -> Details:
        return Details(unk1 = read_uints(file,1),
                         name = read_name(file),
                         color_0 = read_floats(file,4),
                         color_1 = read_floats(file,4),
                         color_2 = read_floats(file,4),
                         color_3 = read_floats(file,4),
                         color_4 = read_floats(file,4),
                         unk2 = read_uints(file,1))

def recursively_link_shader_mix_nodes(nodes, tree, spacing: float = 300):
    #Mostly slopped. This was better than i made previously, lol. I like it.

    if len(nodes) == 1: return nodes[0]

    horiz_step = 0
    while len(nodes) > 1:
        next_nodes = []
        for i in range(0, len(nodes), 2):
            a = nodes[i]
            b = nodes[i + 1] if i + 1 < len(nodes) else None
            if b is None:
                next_nodes.append(a)
                continue

            mix = tree.nodes.new("ShaderNodeMix")
            
            mix.data_type,mix.blend_type = 'RGBA','ADD'
            mix.inputs[0].default_value = 0.5
            mix.inputs[6].default_value = (0,0,0,1)
            mix.inputs[7].default_value = (0,0,0,1)

            tree.links.new(a.outputs['Result'] if 'Result' in a.outputs else a.outputs['Color'], #Could either be a mix node or an image node. Use the corresponding output name.
                           mix.inputs['A'])

            tree.links.new(b.outputs['Result'] if 'Result' in b.outputs else b.outputs['Color'],
                           mix.inputs['B'])

            mix.location.x = horiz_step * spacing

            mix.location.y = (a.location.y + b.location.y) / 2 #Put it between the previous two nodes
            next_nodes.append(mix)
        nodes = next_nodes
        horiz_step += 1
    return nodes[0]

@dataclass
class Mask:
    unk: int = 0
    @classmethod
    def parse(cls, file: BufferedReader) -> Mask:
        raise Exception(f'The mask structure is not known yet! Mask starts @ {hex(file.tell())} in {file.name}')

@dataclass
class FTB:
    rfp: RFP | None = None
    version:  int = 3
    unk1:     int = 0x0
    name:     str = ''
    unk_data: bytes = b''
    brush_dict:       dict[str,Brush]      = field(default_factory = dict)
    mixed_brush_dict: dict[str,MixedBrush] = field(default_factory = dict)
    details:          list[Details]        = field(default_factory = list)
    masks:     int = 0x0
    @classmethod
    def parse(cls, file: BufferedReader, version: int = 3) -> FTB:
        ftb = FTB()
        ftb.version = version
        ftb.unk1 = read_uints(file,1)
        ftb.name = read_name(file)
        ftb.unk_data = file.read(0x8 if version == 1 else 0x78) #Pallete?
        brushes = [Brush.parse(file,version) for _ in range(read_uints(file,1))]
        ftb.brush_dict = {brush.name.lower():brush for brush in brushes}
        mixed_brushes = [MixedBrush.parse(ftb, file) for _ in range(read_uints(file,1))]
        ftb.mixed_brush_dict = {mbrush.name:mbrush for mbrush in mixed_brushes}
        ftb.details = [Details.parse(file) for _ in range(read_uints(file,1))]
        ftb.masks   = [Mask.parse(file) for _ in range(read_uints(file,1))]
        return ftb
    def get_brush(self, name: str, all_known: bool = False) -> Brush | MixedBrush | None:
        if brush := self.brush_dict.get(name): return brush
        elif not all_known: return self.mixed_brush_dict.setdefault(name,MixedBrush(name))
        elif brush := self.mixed_brush_dict.get(name): return brush
        else: 
            print(f'Failed to get brush {name}')
            return None
    def build_brushes(self, rfp: RFP, brushes_to_build: list[str]) -> tuple[bpy.types.Material,list[str]]:
        mat = bpy.data.materials.get(self.name) or bpy.data.materials.new(self.name)
        node_tree = mat.node_tree
        nodes,links = node_tree.nodes,node_tree.links
        nodes.clear()
        links.clear()
        node_tree_dict = {}
        brush_nodes = [(self.get_brush(name.lower()).build(rfp, node_tree, node_tree_dict),name) for name in brushes_to_build if self.get_brush(name,True)]
        mix_nodes = []
        # base_brush = self.get_brush(list(self.mixed_brush_dict.keys())[0]).build(rfp, node_tree, node_tree_dict)
        for i,(b_node,name) in enumerate(brush_nodes):
            attr_node = nodes.new('ShaderNodeAttribute')
            attr_node.attribute_name = name

            mix_node = nodes.new(type = 'ShaderNodeMix')
            mix_node.data_type,mix_node.blend_type = 'RGBA','ADD'
            mix_node.inputs[6].default_value = (0.0,0.0,0.0,1.0)
            links.new(attr_node.outputs['Factor'],mix_node.inputs['Factor'])
            # links.new(base_brush.outputs['Color'],mix_node.inputs['A'])
            links.new(b_node.outputs['Color'],mix_node.inputs['B'])
            mix_nodes.append(mix_node)

            b_node.location = (-600, (-i-.6) * 300)
            attr_node.location = (-600, -i*300)
            mix_node.location = (-300, -i * 300)
            

        final_mix_node = recursively_link_shader_mix_nodes(mix_nodes, node_tree)

        output_node = node_tree.nodes.new(type = 'ShaderNodeOutputMaterial')
        node_tree.links.new(final_mix_node.outputs['Result'], output_node.inputs['Surface'])
        output_node.location = final_mix_node.location.x + 300, final_mix_node.location.y

        return mat,[name for node,name in brush_nodes]
    def __repr__(self):
        return f"FTB(version={self.version}, name={self.name}, brushes={len(self.brush_dict)}, mixed_brushes={len(self.mixed_brush_dict)})"

if __name__ == '__main__':
    rfp = RFP.parse(r'C:\Program Files (x86)\Steam\steamapps\common\Exanima')
    # file_path = r'C:\Program Files (x86)\Steam\steamapps\common\Exanima\Resource\uwa1.ftb'
    file_path = r'C:\Program Files (x86)\Steam\steamapps\common\Exanima\Resource\default.ftb'
    with open(file_path,'rb') as file:
        signature = read_uints(file,1)
        if signature & 0xFFFFFF00 != 0x3EEFBD00: raise Exception(f'{file_path} is not a ftb!')
        ftb = FTB.parse(file, version = signature & 0xFF)
        