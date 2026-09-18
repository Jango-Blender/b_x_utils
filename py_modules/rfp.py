from __future__ import annotations

from .rfc import parse_rfc,SortedTileset

from .parsing_funcs import *
from .rpk import RPK

from .rdb.items import ItemDB,Item
from .rdb.chars import Character
from .rdb.races import RaceDB
from .rdb.charroles import RoleDB
from .rdb.locales import LocaleDB

from .pwr import PowerTree

from dataclasses import dataclass,field
from typing import ClassVar

from . import b_funcs as bf

import bpy

import os

def check_if_should_merge_obj(obj: bpy.types.Object) -> bool:
    if '+F' in obj.name: return False
    elif not obj.data: return False
    elif not obj.data.materials: return False
    #Ignore only "black" objects
    elif [mat for mat in obj.data.materials if mat.name.lower() != 'black' and mat.name.lower() != '_null' and mat.name.lower() != '_black']: return True

@dataclass
class RFP:
    dir:       str = ''
    signature: int = 0xAFDFBD10
    flags:     int = 0x0
    name:      str = ''
    null:      bytes = b''
    resource:      RPK = field(default_factory = RPK)
    objlibs:       list[RPK] = field(default_factory = list)
    textures:      list[RPK] = field(default_factory = list)
    rml_paths:     list[str] = field(default_factory = list)
    objects:       RPK = field(default_factory = RPK)
    factories:     RPK = field(default_factory = RPK)
    components:    RPK = field(default_factory = RPK)
    componenttex:  RPK = field(default_factory = RPK)
    characters:    RPK = field(default_factory = RPK)
    apparel:       RPK = field(default_factory = RPK)
    itemdb:        ItemDB = field(default_factory = ItemDB)
    racedb:        RaceDB = field(default_factory = RaceDB)
    old_race_names: list[str] = field(default_factory = list)
    roledb:        RoleDB = field(default_factory = RoleDB)
    pwrs:          list[PowerTree] = field(default_factory = list)
    locales:       LocaleDB = field(default_factory = LocaleDB)

    built_images: dict[str,bpy.types.Image] = field(default_factory = dict)
    
    built_props: dict[str,list[bpy.types.Object]]        = field(default_factory = dict)
    built_world_models: dict[str,list[bpy.types.Object]] = field(default_factory = dict)
    built_char_models: dict[str,list[bpy.types.Object]]  = field(default_factory = dict)
    built_race_models: dict[str,list[bpy.types.Object]]  = field(default_factory = dict)

    built_items: dict[Item,bpy.types.Object]      = field(default_factory = dict)
    built_chars: dict[Character,bpy.types.Object] = field(default_factory = dict)

    role_names: ClassVar[list[str]] = []
    spell_names: ClassVar[list[str]] = []
    @classmethod
    def parse(cls, file_directory: str) -> RFP:
        rfp_path = os.path.join(file_directory,'Exanima.rfp')
        if not os.path.exists(rfp_path): raise Exception(f'File directory ({file_directory}) does not contain Exanima.rfp!')
        file = open(rfp_path,'rb')
        (signature,flags),name,null = read_uints(file,2),read_name(file),file.read(4)
        resource = RPK.parse(rpk_path = os.path.join(file_directory,read_string(file)+'.rpk'))
        return RFP(dir = dir,
                   signature = signature,
                   flags = flags,
                   name = name,
                   null = name,
                   resource     = resource,
                   objlibs      = [RPK.parse(rpk_path = os.path.join(file_directory,read_string(file)+'.rpk')) for _ in range(read_uints(file,1))],
                   textures     = [RPK.parse(rpk_path = os.path.join(file_directory,read_string(file)+'.rpk')) for _ in range(read_uints(file,1))],
                   rml_paths    = [read_string(file).lower() for _ in range(read_uints(file,1))],
                   objects      = RPK.parse(rpk_path = os.path.join(file_directory,'Objects.rpk')),
                   factories    = RPK.parse(rpk_path = os.path.join(file_directory,'Factories.rpk')),
                   components   = RPK.parse(rpk_path = os.path.join(file_directory,'Components.rpk')),
                   componenttex = RPK.parse(rpk_path = os.path.join(file_directory,'Componenttex.rpk')),
                   characters   = RPK.parse(rpk_path = os.path.join(file_directory,'Characters.rpk')),
                   apparel      = RPK.parse(rpk_path = os.path.join(file_directory,'Apparel.rpk')),
                   #Investigate how to optimize the stuff after this
                   itemdb       = resource.parse_itemdb(),
                   racedb       = resource.parse_entry('races.rdb') if 'races.rdb' in resource.lookup_table else None,
                   old_race_names = ['human', 'skel', 'ancient', 'ogre', 'hrtogr', 'hrtafael', 'hrtaghla', 'hrtaghlh', 'gobbler', 'tntclskl',
                                      'shdwskel', 'manipula', 'holyskel', 'embrskel', #Hellmode races
                                      '', 'wraithha', 'golem', 'glmbsa', 'glmsta', ''],
                   roledb       = resource.parse_entry('charroles.rdb'),
                   pwrs         = {1: resource.parse_entry('pwr_mind.pwr'),
                                   2: resource.parse_entry('pwr_force.pwr'),
                                   3: None,
                                   4: resource.parse_entry('pwr_energy.pwr') if 'pwr_energy.pwr' in resource.lookup_table else None,
                                   5: None,
                                   6: resource.parse_entry('pwr_displace.pwr') if 'pwr_displace.pwr' in resource.lookup_table else None},
                   locales      = resource.parse_entry('locales.rdb'))
    def __repr__(self):
        return f'RFP(path={self.dir})'
    @classmethod
    def get_role_names(cls, exanima_dir: str) -> list[str]:
        if not RFP.role_names: #Only do this stuff once.
            rfp_path = os.path.join(exanima_dir,'Exanima.rfp')
            if not os.path.exists(rfp_path): return [('N/A','N/A','')]
            rfp = RFP.parse(exanima_dir)
            RFP.role_names = [(name,name,'') for name in rfp.roledb.get_names()]
        return RFP.role_names
    def get_image(self, image_name: str) -> bpy.types.Image | None:
        # print(f'Attempting to get image {image_name}')
        if image_name in self.built_images: return self.built_images[image_name]
        if image := bpy.data.images.get(image_name): 
            self.built_images[image_name] = image
            return image
        for tex_rpk in self.textures:
            if image_name in tex_rpk.lookup_table:
                image = tex_rpk.parse_entry(image_name)
                self.built_images[image_name] = image
                return image
        else:
            print(f'Failed to find image {image_name} in texture rpks {self.textures}')
            return None
    def get_set(self, set_name: str) -> SortedTileset:
        print(f'Attempting to get tileset {set_name}')
        import_name = set_name
        set_name = set_name[:-4].lower() #Cut off .rfc and make it lowercase.
        #Store them in the blend file and reuse them. Prevents performing these expensive mergers.
        if set_name in bpy.data.collections: return SortedTileset.sort(name = set_name, objs = bpy.data.collections[set_name].objects) 
        set_col = bpy.data.collections.new(set_name)
        print(f'Importing tileset {import_name}')
        raw_objs = self.resource.parse_entry(import_name, self, None, True)
        roots = [obj for obj in raw_objs if not obj.parent]
        print(f'\tMerging {len(roots)} hierarchies...')
        mobjs = [bf.merge_hierarchy(hierarchy = [root] + [child for child in root.children_recursive if check_if_should_merge_obj(child)], col = set_col) for root in roots]
        for obj in mobjs: obj.tileset = set_name
        return SortedTileset.sort(name = set_name, objs = mobjs)
    def get_prop(self, prop_name: str, col: bpy.types.Collection | None) -> list[bpy.types.Object] | None:
        if prop_name in self.built_props:
            return bf.copy_objects(self.built_props[prop_name], col)
        # print(f'Getting prop {prop_name}')
        for objlib in self.objlibs:
            if prop_name in objlib.lookup_table:
                objs = objlib.parse_entry(prop_name, self, None, True)
                if col:
                    for obj in objs: col.objects.link(obj)
                self.built_props[prop_name] = objs
                return objs
        else: 
            print(f'Failed to get prop ({prop_name})')
            return None
    def get_world_model(self, model_name: str, col: bpy.types.Collection) -> list[bpy.types.Object] | None:
        model_name = model_name.lower()
        if model_name in self.built_world_models:
            return bf.copy_objects(self.built_world_models[model_name], col)
        elif model_name in self.objects.lookup_table:
            objs = self.objects.parse_entry(model_name, self, None, True)
            if col:
                for obj in objs: col.objects.link(obj)
            self.built_world_models[model_name] = objs
            return objs
        else:
            objs = [bf.create_empty(name = model_name, col = col)]
            self.built_world_models[model_name] = objs
            return objs
        #     raise Exception(f'Failed to get world model ({model_name}) from rpk {self.objects.file}')
    def get_race_model(self, model_name: str, col: bpy.types.Collection) -> list[bpy.types.Object] | None:
        model_name = model_name.lower()
        if model_name in self.built_race_models:
            return bf.copy_objects(self.built_race_models[model_name], col)
        elif model_name in self.resource.lookup_table:
            objs = self.resource.parse_entry(model_name, self, None, True)
            for obj in objs: obj.is_race_base = True #Helper
            if col:
                for obj in objs: col.objects.link(obj)
            self.built_race_models[model_name] = objs
            return objs
        else: 
            raise Exception(f'Failed to get race model {model_name}')