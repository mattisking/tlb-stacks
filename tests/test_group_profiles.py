import json
import os
from pathlib import Path
import tempfile
import unittest
import zipfile
from test_profiles import profile


class GroupProfiles(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.old_data = os.environ.get('XDG_DATA_HOME')
        os.environ['XDG_DATA_HOME'] = str(self.root / 'destination')
        self.image = self.root / 'custom.svg'
        self.image.write_text('<svg xmlns="http://www.w3.org/2000/svg"/>')
        self.archive = self.root / 'group.zip'
        self.settings = dict(applications=['editor', 'tlbstacks-separator:1:Tools'],
                             groupName='Development', groupIcon=str(self.image),
                             applicationIcons={'editor': str(self.image)})
        self.group = dict(groupName='My panel', items=[
            dict(id='launch', type='application', desktopId='missing.desktop'),
            dict(id='stack', type='stack', settings=self.settings)])

    def tearDown(self):
        if self.old_data is None:
            os.environ.pop('XDG_DATA_HOME', None)
        else:
            os.environ['XDG_DATA_HOME'] = self.old_data
        self.temp.cleanup()

    def export(self, **extra):
        return profile.handle(dict(action='exportGroup', file=str(self.archive), group=self.group, **extra))

    def imported(self, **extra):
        return profile.handle(dict(action='importGroup', file=str(self.archive), **extra))

    def rewrite(self, change):
        with zipfile.ZipFile(self.archive) as archive:
            data = {name: archive.read(name) for name in archive.namelist()}
        manifest = json.loads(data['profile.json'])
        change(manifest)
        data['profile.json'] = json.dumps(manifest)
        with zipfile.ZipFile(self.archive, 'w') as archive:
            for name, value in data.items():
                archive.writestr(name, value)

    def test_launcher_appearance_round_trip_and_shared_asset(self):
        self.group['items'][0].update(label='My editor', icon=str(self.image))
        self.export()
        with zipfile.ZipFile(self.archive) as archive:
            manifest = json.loads(archive.read('profile.json'))
            self.assertEqual(manifest['version'], 2)
            self.assertEqual(len(archive.namelist()), 2)
        self.image.unlink()
        result = self.imported()['group']['items']
        self.assertEqual(result[0]['label'], 'My editor')
        self.assertEqual(result[0]['icon'], result[1]['settings']['groupIcon'])
        self.assertTrue(Path(result[0]['icon']).is_file())
        self.assertEqual(result[0]['desktopId'], 'missing.desktop')

    def test_invalid_launcher_icon_prevents_all_asset_writes(self):
        self.group['items'][0]['icon'] = str(self.image)
        self.export()
        self.rewrite(lambda data: data['group']['items'][0].update(icon='assets/' + '0' * 64 + '.png'))
        with self.assertRaises(ValueError):
            self.imported()
        self.assertFalse((self.root / 'destination/tlbstacks/icons').exists())

    def test_launcher_label_is_validated(self):
        self.group['items'][0]['label'] = 'x' * 257
        with self.assertRaises(ValueError):
            self.export()

    def test_all_sources_order_images_and_relocation(self):
        for source in ['categories', 'activity', 'folder']:
            settings = dict(self.settings, menuSource=source,
                            applicationCategories=['Development'], activityOrder='frequent', activityLimit=7,
                            folderUrl=(self.root / 'alice/Documents/Tools').as_uri(), folderFilters='*.pdf')
            self.group['items'].append(dict(id=source, type='stack', settings=settings))
        self.export(standardLocations={'documents': str(self.root / 'alice/Documents')})
        with zipfile.ZipFile(self.archive) as archive:
            self.assertEqual(len([name for name in archive.namelist() if name.startswith('assets/')]), 1)
        self.image.unlink()
        result = self.imported(standardLocations={'documents': str(self.root / 'bob/Dokumente')})
        self.assertEqual(result['kind'], 'group')
        items = result['group']['items']
        self.assertEqual([item['id'] for item in items], ['launch', 'stack', 'categories', 'activity', 'folder'])
        self.assertEqual(items[0]['desktopId'], 'missing.desktop')
        self.assertEqual(items[1]['settings']['applications'][1], 'tlbstacks-separator:1:Tools')
        self.assertTrue(Path(items[1]['settings']['groupIcon']).is_file())
        self.assertEqual(items[1]['settings']['groupIcon'], items[1]['settings']['applicationIcons']['editor'])
        self.assertEqual(items[-1]['settings']['folderUrl'], (self.root / 'bob/Dokumente/Tools').as_uri())
        self.assertEqual(items[-2]['settings']['activityLimit'], 7)
        self.assertTrue(result['folderMissing'])

    def test_single_stack_interoperability(self):
        profile.export_profile(dict(file=str(self.archive), settings=self.settings))
        imported = self.imported()
        self.assertEqual(imported['kind'], 'stack')
        self.assertEqual(imported['settings']['applications'], self.settings['applications'])
        self.group['items'][1]['settings'] = imported['settings']
        self.export()
        restored = self.imported()['group']['items'][1]['settings']
        profile.export_profile(dict(file=str(self.archive), settings=restored))
        self.assertEqual(profile.import_profile(dict(file=str(self.archive)))['settings'], restored)

    def test_group_rejected_by_standalone_import(self):
        self.export()
        with self.assertRaises(ValueError):
            profile.import_profile(dict(file=str(self.archive)))
        self.assertFalse(profile.storage().exists())

    def test_invalid_later_stack_does_not_write_assets(self):
        self.group['items'].append(dict(id='bad', type='stack', settings=dict(self.settings)))
        self.export()
        def corrupt(manifest):
            manifest['group']['items'][-1]['settings']['groupIcon'] = 'assets/' + 'a' * 64 + '.png'
        self.rewrite(corrupt)
        with self.assertRaises(ValueError):
            self.imported()
        self.assertFalse(profile.storage().exists())

    def test_duplicate_ids_unknown_types_and_limits(self):
        for items in [[self.group['items'][0]] * 2, [dict(id='x', type='command')],
                      [dict(id=str(i), type='application', desktopId='app') for i in range(501)]]:
            with self.subTest(items=len(items)), self.assertRaises(ValueError):
                profile.validate_group(dict(groupName='', items=items))

    def test_portable_traversal_rejected_before_writes(self):
        self.export()
        def corrupt(manifest):
            manifest['group']['items'][1]['folderLocation'] = dict(base='home', path='../escape')
        self.rewrite(corrupt)
        with self.assertRaises(ValueError):
            self.imported(standardLocations={'home': str(self.root)})
        self.assertFalse(profile.storage().exists())

    def test_future_group_version_rejected(self):
        self.export()
        self.rewrite(lambda manifest: manifest.update(version=99))
        with self.assertRaises(ValueError):
            self.imported()

    def test_empty_group_roundtrip(self):
        self.group['items'] = []
        self.export()
        self.assertEqual(self.imported()['group'], self.group)

    def test_export_cannot_replace_group_source_image(self):
        original = self.image.read_bytes()
        with self.assertRaises(ValueError):
            profile.export_group(dict(group=self.group, file=str(self.image)))
        self.assertEqual(self.image.read_bytes(), original)
