import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
import zipfile

spec = importlib.util.spec_from_file_location('profile_helper', Path(__file__).parents[1] / 'package/contents/code/profile.py')
profile = importlib.util.module_from_spec(spec)
spec.loader.exec_module(profile)

class Profiles(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.previous = os.environ.get('XDG_DATA_HOME')
        os.environ['XDG_DATA_HOME'] = str(self.root / 'machine-a')
        self.image = self.root / 'custom icon #1.svg'
        self.image.write_text('<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16"><rect width="16" height="16" fill="red"/></svg>')
        self.settings = dict(groupName='Development ☕', groupIcon=str(self.image),
            applications=['test.editor', 'test.missing'], applicationIcons={'test.editor': str(self.image)},
            iconsOnly=True, menuIconSize=32, menuSource='applications', folderUrl='', folderFilters='*', applicationCategories=[], hoverDelay=250)
        self.archive = self.root / 'menu.zip'

    def test_activity_roundtrip_and_defaults(self):
        self.settings.update(groupIcon='applications-all', applicationIcons={},
                             menuSource='activity', activityOrder='frequent',
                             activityLimit=7, activityCurrent=True,
                             applicationCategories=['Development'])
        self.export()
        result = profile.import_profile(dict(file=str(self.archive)))['settings']
        self.assertEqual(result, profile.validate_settings(self.settings))
        self.write_manifest(settings=dict(self.settings, groupIcon='applications-all', applicationIcons={}), version=4)
        self.assertEqual(profile.import_profile(dict(file=str(self.archive)))['settings']['activityLimit'], 7)
        old = dict(self.settings)
        for field in ('activityOrder', 'activityLimit', 'activityCurrent'): old.pop(field)
        defaults = profile.validate_settings(old)
        self.assertEqual(defaults['activityOrder'], 'recent')
        self.assertEqual(defaults['activityLimit'], 10)
        self.assertFalse(defaults['activityCurrent'])

    def test_invalid_activity_settings(self):
        for key, value in [('activityOrder', 'wrong'), ('activityLimit', 0),
                           ('activityLimit', 51), ('activityLimit', True),
                           ('activityCurrent', 'yes')]:
            with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                profile.validate_settings(dict(self.settings, **{key: value}))

    def test_category_roundtrip(self):
        self.settings.update(menuSource='categories', applicationCategories=['Development', 'IDE'])
        self.settings['applicationIcons']['dynamic.app'] = str(self.image)
        self.export()
        result = profile.handle(dict(action='import', file=str(self.archive)))['settings']
        self.assertEqual(result['menuSource'], 'categories')
        self.assertEqual(result['applicationCategories'], ['Development', 'IDE'])
        self.assertIn('dynamic.app', result['applicationIcons'])

    def test_invalid_categories(self):
        for value in ['Development', [''], ['IDE', 'IDE'], [42]]:
            with self.subTest(value=value), self.assertRaises(ValueError):
                profile.validate_settings(dict(self.settings, applicationCategories=value))

    def test_old_profile_defaults_categories(self):
        settings = dict(self.settings)
        settings.pop('applicationCategories')
        self.assertEqual(profile.validate_settings(settings)['applicationCategories'], [])

    def test_hover_delay(self):
        for delay in [0, 75, 250, 2000]:
            self.settings['hoverDelay'] = delay
            self.export()
            result = profile.handle(dict(action='import', file=str(self.archive)))['settings']
            self.assertEqual(result['hoverDelay'], delay)
        old = dict(self.settings)
        old.pop('hoverDelay')
        self.assertEqual(profile.validate_settings(old)['hoverDelay'], 250)
        for invalid in [-1, 2001, True, 'fast']:
            with self.subTest(invalid=invalid), self.assertRaises(ValueError):
                profile.validate_settings(dict(old, hoverDelay=invalid))

    def tearDown(self):
        if self.previous is None:
            os.environ.pop('XDG_DATA_HOME', None)
        else:
            os.environ['XDG_DATA_HOME'] = self.previous
        self.tmp.cleanup()

    def export(self):
        return profile.handle(dict(action='export', file=self.archive.as_uri(), settings=self.settings))

    def test_round_trip_different_machine_without_original(self):
        self.export()
        self.image.unlink()
        os.environ['XDG_DATA_HOME'] = str(self.root / 'machine-b')
        result = profile.handle(dict(action='import', file=str(self.archive)))['settings']
        self.assertEqual(result['applications'], self.settings['applications'])
        self.assertEqual(result['groupName'], 'Development ☕')
        self.assertEqual(result['menuIconSize'], 32)
        self.assertTrue(result['iconsOnly'])
        self.assertEqual(result['groupIcon'], result['applicationIcons']['test.editor'])
        self.assertTrue(Path(result['groupIcon']).is_file())
        self.assertTrue(result['groupIcon'].startswith(str(self.root / 'machine-b')))
        with zipfile.ZipFile(self.archive) as archive:
            self.assertEqual(len(archive.namelist()), 2)
            self.assertNotIn(str(self.root), archive.read('profile.json').decode())

    def test_manage_file_uri_preserves_copy(self):
        result = profile.handle(dict(action='manageIcon', icon=self.image.as_uri()))
        second = profile.handle(dict(action='manageIcon', icon=str(self.image)))
        self.assertEqual(result['icon'], second['icon'])
        self.image.unlink()
        self.assertTrue(Path(result['icon']).exists())

    def test_theme_names_stay_names(self):
        self.settings['groupIcon'] = 'applications-all'
        self.settings['applicationIcons'] = {'test.editor': 'vscode'}
        self.export()
        result = profile.handle(dict(action='import', file=str(self.archive)))['settings']
        self.assertEqual(result, profile.validate_settings(self.settings))

    def test_missing_original_does_not_replace_export(self):
        self.archive.write_bytes(b'existing export')
        self.image.unlink()
        with self.assertRaises(OSError):
            self.export()
        self.assertEqual(self.archive.read_bytes(), b'existing export')

    def write_manifest(self, settings=None, version=1, extra=None, format_name="TLBStacks"):
        with zipfile.ZipFile(self.archive, 'w') as archive:
            archive.writestr('profile.json', json.dumps(dict(format=format_name, version=version,
                settings=settings or dict(self.settings, groupIcon='applications-all', applicationIcons={}))))
            if extra:
                archive.writestr(*extra)

    def test_legacy_brand_profiles(self):
        for version in (1, 2, 3):
            with self.subTest(version=version):
                self.write_manifest(version=version, format_name="TrueLaunchBar")
                result = profile.import_profile(dict(file=str(self.archive)))
                self.assertEqual(result['settings']['groupName'], self.settings['groupName'])

    def test_unknown_brand_rejected(self):
        self.write_manifest(format_name="OtherApplication")
        with self.assertRaises(ValueError):
            profile.import_profile(dict(file=str(self.archive)))

    def test_path_traversal_rejected(self):
        self.write_manifest(extra=('../outside.svg', b'bad'))
        with self.assertRaises(ValueError):
            profile.import_profile(dict(file=str(self.archive)))
        self.assertFalse(profile.storage().exists())

    def test_external_reference_rejected(self):
        self.write_manifest(settings=self.settings)
        with self.assertRaises(ValueError):
            profile.import_profile(dict(file=str(self.archive)))

    def test_future_version_rejected(self):
        self.write_manifest(version=99)
        with self.assertRaises(ValueError):
            profile.import_profile(dict(file=str(self.archive)))

    def test_corrupt_asset_rejected_before_writes(self):
        name = 'assets/' + '0' * 64 + '.svg'
        self.write_manifest(settings=dict(self.settings, groupIcon=name, applicationIcons={}), extra=(name, b'bad'))
        with self.assertRaises(ValueError):
            profile.import_profile(dict(file=str(self.archive)))
        self.assertFalse(profile.storage().exists())

    def test_missing_asset_rejected(self):
        self.write_manifest(settings=dict(self.settings, groupIcon='assets/' + 'a' * 64 + '.png', applicationIcons={}))
        with self.assertRaises(ValueError):
            profile.import_profile(dict(file=str(self.archive)))

    def test_bad_settings_rejected(self):
        for change in [dict(menuIconSize=99), dict(iconsOnly='yes'), dict(applications=['same', 'same'])]:
            with self.subTest(change=change), self.assertRaises(ValueError):
                profile.validate_settings(dict(self.settings, **change))

    def test_size_limit_rejected(self):
        self.write_manifest(extra=('assets/' + 'a' * 64 + '.png', b'a' * (profile.MAX_IMAGE + 1)))
        with self.assertRaises(ValueError):
            profile.import_profile(dict(file=str(self.archive)))

    def test_cannot_overwrite_source_icon(self):
        with self.assertRaises(ValueError):
            profile.export_profile(dict(file=str(self.image), settings=self.settings))
        self.assertIn('<svg', self.image.read_text())

    def test_folder_round_trip_preserves_reference_not_contents(self):
        folder = self.root / 'tools'
        folder.mkdir()
        (folder / 'secret.txt').write_text('do not bundle')
        self.settings.update(menuSource='folder', folderUrl=folder.as_uri(), folderFilters='*.pdf;*.desktop')
        self.export()
        result = profile.import_profile(dict(file=str(self.archive)))['settings']
        self.assertEqual(result['folderUrl'], folder.as_uri())
        self.assertEqual(result['folderFilters'], '*.pdf;*.desktop')
        with zipfile.ZipFile(self.archive) as archive:
            self.assertFalse(any('secret' in name for name in archive.namelist()))

    def test_legacy_profile_defaults_to_application_menu(self):
        settings = dict(self.settings, groupIcon='applications-all', applicationIcons={})
        for key in ('menuSource', 'folderUrl', 'folderFilters'):
            settings.pop(key)
        self.write_manifest(settings=settings, version=1)
        result = profile.import_profile(dict(file=str(self.archive)))['settings']
        self.assertEqual(result['menuSource'], 'applications')
        self.assertEqual(result['folderUrl'], '')

    def test_remote_folder_rejected(self):
        with self.assertRaises(ValueError):
            profile.validate_settings(dict(self.settings, menuSource='folder', folderUrl='https://example.com'))

if __name__ == '__main__':
    unittest.main()
