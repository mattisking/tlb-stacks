"""TLBStacks profile transport. JSON stdin/stdout; Python standard library only."""
import hashlib
import io
import json
import os
from pathlib import Path
import re
import sys
import tempfile
from urllib.parse import unquote, urlparse
import zipfile

MAX_IMAGE = 10 * 1024 * 1024
MAX_TOTAL = 64 * 1024 * 1024
MAX_JSON = 1024 * 1024
EXTENSIONS = {'.png', '.svg', '.svgz', '.jpg', '.jpeg', '.webp', '.ico'}
ASSET = re.compile(r'assets/[0-9a-f]{64}\.(png|svg|svgz|jpg|jpeg|webp|ico)\Z')


def local_path(value):
    if not isinstance(value, str) or not value:
        raise ValueError('Choose a local file.')
    if value.startswith('file:'):
        url = urlparse(value)
        if url.netloc not in ('', 'localhost') or url.query or url.fragment:
            raise ValueError('Only local files are supported.')
        value = unquote(url.path)
    path = Path(value)
    if not path.is_absolute():
        raise ValueError('Choose an absolute local file path.')
    return path


def storage():
    root = os.environ.get('XDG_DATA_HOME') or str(Path.home() / '.local/share')
    return Path(root) / 'tlbstacks/icons'


def atomic_write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix='.tlb-', dir=path.parent)
    try:
        with os.fdopen(fd, 'wb') as stream:
            stream.write(data)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def image_data(path):
    if path.suffix.lower() not in EXTENSIONS:
        raise ValueError('Unsupported icon image format.')
    with path.open('rb') as stream:
        data = stream.read(MAX_IMAGE + 1)
    if not data or len(data) > MAX_IMAGE:
        raise ValueError('Icon images must be between 1 byte and 10 MiB.')
    return data


def store_image(data, suffix):
    path = storage() / (hashlib.sha256(data).hexdigest() + suffix.lower())
    if not path.exists() or path.read_bytes() != data:
        atomic_write(path, data)
    return str(path)


def text(value, label, limit=512):
    if not isinstance(value, str) or len(value) > limit or '\x00' in value:
        raise ValueError('Invalid ' + label + '.')
    return value


def validate_settings(settings):
    if not isinstance(settings, dict):
        raise ValueError('Missing menu settings.')
    apps = settings.get('applications')
    if not isinstance(apps, list) or len(apps) > 2000:
        raise ValueError('Invalid application list.')
    apps = [text(app, 'application ID') for app in apps]
    if any(not app for app in apps) or len(set(apps)) != len(apps):
        raise ValueError('Application IDs must be nonempty and unique.')
    icons = settings.get('applicationIcons', {})
    if not isinstance(icons, dict) or len(icons) > 2000:
        raise ValueError('Invalid application icon settings.')
    for key, value in icons.items():
        text(key, 'icon application ID')
        text(value, 'icon', 4096)
    size = settings.get('menuIconSize', 22)
    if type(size) is not int or not 16 <= size <= 64:
        raise ValueError('Menu icon size must be between 16 and 64.')
    delay = settings.get('hoverDelay', 250)
    if type(delay) is not int or not 0 <= delay <= 2000:
        raise ValueError('Hover delay must be between 0 and 2000 milliseconds.')
    mode = settings.get('iconsOnly', False)
    if type(mode) is not bool:
        raise ValueError('Invalid menu display mode.')
    source = settings.get('menuSource', 'applications')
    if source not in ('applications', 'folder', 'categories', 'activity'):
        raise ValueError('Unknown menu source.')
    activity_order = settings.get('activityOrder', 'recent')
    activity_limit = settings.get('activityLimit', 10)
    activity_current = settings.get('activityCurrent', False)
    if activity_order not in ('recent', 'frequent'):
        raise ValueError('Invalid activity order.')
    if type(activity_limit) is not int or not 1 <= activity_limit <= 50:
        raise ValueError('Activity limit must be between 1 and 50.')
    if type(activity_current) is not bool:
        raise ValueError('Invalid activity scope.')
    categories = settings.get('applicationCategories', [])
    if not isinstance(categories, list) or len(categories) > 512:
        raise ValueError('Invalid application categories.')
    categories = [text(value, 'category') for value in categories]
    if any(not value for value in categories) or len(set(categories)) != len(categories):
        raise ValueError('Categories must be nonempty and unique.')
    folder = text(settings.get('folderUrl', ''), 'folder location', 4096)
    if folder:
        folder = local_path(folder).as_uri()
    filters = text(settings.get('folderFilters', '*'), 'file patterns', 4096)
    return dict(activityOrder=activity_order, activityLimit=activity_limit, activityCurrent=activity_current, menuSource=source, applicationCategories=categories, folderUrl=folder, folderFilters=filters,
                groupName=text(settings.get('groupName', ''), 'menu name', 256),
                groupIcon=text(settings.get('groupIcon', 'applications-all'), 'menu icon', 4096),
                applications=apps, applicationIcons=dict(icons),
                iconsOnly=mode, menuIconSize=size, hoverDelay=delay)


def map_icons(settings, transform):
    result = dict(settings)
    if settings.get('type') == 'application':
        if settings.get('icon'):
            result['icon'] = transform(settings['icon'])
        return result
    result['groupIcon'] = transform(settings['groupIcon'])
    result['applicationIcons'] = {key: transform(value)
                                  for key, value in settings['applicationIcons'].items()}
    return result


def theme_icon(value):
    if '/' in value or '\\' in value or ':' in value or value in ('.', '..'):
        raise ValueError('Invalid theme icon reference: ' + value)
    return value


# These locations come from Qt on the running machine, never from the ZIP.
STANDARD_LOCATIONS = ('documents', 'downloads', 'desktop', 'music', 'pictures', 'videos', 'home')


def standard_locations(request):
    locations = request.get('standardLocations', {})
    return {key: local_path(locations[key]) for key in STANDARD_LOCATIONS
            if locations.get(key)}


def portable_folder(folder, request):
    if not folder:
        return None
    path = local_path(folder)
    locations = standard_locations(request)
    # Prefer the most specific directory; Home is the last tie-breaker.
    for key, base in sorted(locations.items(), key=lambda item: -len(item[1].parts)):
        if key != 'home' and base == locations.get('home'):
            continue  # XDG folders disabled by mapping them to Home.
        try:
            relative = path.relative_to(base)
        except ValueError:
            continue
        if '..' not in relative.parts:
            return dict(base=key, path=relative.as_posix())
    return None


def restore_folder(reference, request):
    if not isinstance(reference, dict) or set(reference) != {'base', 'path'}:
        raise ValueError('Invalid portable folder reference.')
    base = reference['base']
    if not isinstance(base, str) or base not in STANDARD_LOCATIONS:
        raise ValueError('Unknown standard folder.')
    relative = text(reference['path'], 'relative folder path', 4096)
    path = Path(relative)
    if not relative or path.is_absolute() or '..' in path.parts:
        raise ValueError('Invalid relative folder path.')
    locations = standard_locations(request)
    if base not in locations:
        raise ValueError('The destination standard folder is unavailable: ' + base)
    return (locations[base] / path).as_uri()


def validate_group(group, allow_references=False):
    if not isinstance(group, dict) or not isinstance(group.get('items'), list) or len(group['items']) > 500:
        raise ValueError('Invalid group settings.')
    items, ids = [], set()
    for value in group['items']:
        if not isinstance(value, dict):
            raise ValueError('Invalid group entry.')
        identity = text(value.get('id'), 'entry ID')
        if not identity or identity in ids:
            raise ValueError('Group entry IDs must be nonempty and unique.')
        ids.add(identity)
        kind = value.get('type')
        item = dict(id=identity, type=kind)
        if kind == 'application':
            item['desktopId'] = text(value.get('desktopId'), 'application ID')
            for field in ('label', 'icon'):
                if field in value:
                    item[field] = text(value[field], 'launcher ' + field, 256 if field == 'label' else 4096)
            if not item['desktopId']:
                raise ValueError('Missing application ID.')
        elif kind == 'stack':
            item['settings'] = validate_settings(value.get('settings'))
            if 'folderLocation' in value:
                if not allow_references:
                    raise ValueError('Unexpected portable folder reference.')
                item['folderLocation'] = value['folderLocation']
        else:
            raise ValueError('Unsupported group entry type.')
        items.append(item)
    return dict(groupName=text(group.get('groupName', ''), 'group name', 256), items=items)


def pack_folder(settings, container, request):
    reference = portable_folder(settings['folderUrl'], request)
    if reference is not None:
        settings['folderUrl'] = ''
        container['folderLocation'] = reference


def unpack_folder(settings, container, request):
    if 'folderLocation' in container:
        if settings['folderUrl']:
            raise ValueError('Conflicting portable folder settings.')
        settings['folderUrl'] = restore_folder(container.pop('folderLocation'), request)


def write_archive(request, document, settings_list):
    # Shared global limits and asset deduplication across all stacks in a group.
    assets, sources = {}, []
    def pack(value):
        if value.startswith('/') or value.startswith('file:'):
            path = local_path(value)
            sources.append(path)
            data = image_data(path)
            name = 'assets/' + hashlib.sha256(data).hexdigest() + path.suffix.lower()
            assets[name] = data
            if len(assets) > 256 or sum(map(len, assets.values())) > MAX_TOTAL:
                raise ValueError('Too many icon images in this profile (maximum 64 MiB / 256 images).')
            return name
        return theme_icon(value)
    for settings in settings_list:
        settings.update(map_icons(settings, pack))
    manifest = json.dumps(document, ensure_ascii=False, indent=2).encode('utf-8')
    if len(manifest) > MAX_JSON:
        raise ValueError('Profile settings are too large.')
    destination = local_path(request.get('file'))
    if any(destination.resolve() == path.resolve() for path in sources):
        raise ValueError('The export file cannot replace a source icon.')
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, 'w', compression=zipfile.ZIP_DEFLATED) as archive:
        archive.writestr('profile.json', manifest)
        for name, data in assets.items():
            archive.writestr(name, data)
    atomic_write(destination, buffer.getvalue())
    return dict(ok=True, file=str(destination))


def export_profile(request):
    settings = validate_settings(request.get('settings'))
    if settings['menuSource'] != 'categories':
        settings['applicationIcons'] = {key: value for key, value in settings['applicationIcons'].items()
                                        if key in settings['applications']}
    document = dict(format='TLBStacks', version=5, settings=settings)
    pack_folder(settings, document, request)
    return write_archive(request, document, [settings])


def export_group(request):
    group = validate_group(request.get('group'))
    settings_list = []
    for item in group['items']:
        if item['type'] == 'stack':
            pack_folder(item['settings'], item, request)
            settings_list.append(item['settings'])
        else:
            settings_list.append(item)
    version = 2 if any(item['type'] == 'application' and (item.get('label') or item.get('icon')) for item in group['items']) else 1
    return write_archive(request, dict(format='TLBStacksGroup', version=version, group=group), settings_list)


def import_profile(request, allow_group=False):
    source = local_path(request.get('file'))
    if source.stat().st_size > MAX_TOTAL + MAX_JSON:
        raise ValueError('Profile ZIP is too large.')
    with zipfile.ZipFile(source) as archive:
        infos = archive.infolist()
        names = [info.filename for info in infos]
        if len(names) > 257 or len(names) != len(set(names)) or 'profile.json' not in names:
            raise ValueError('Invalid or duplicate ZIP entries.')
        if any(name != 'profile.json' and not ASSET.fullmatch(name) for name in names):
            raise ValueError('Unexpected file in profile ZIP.')
        if sum(info.file_size for info in infos) > MAX_TOTAL + MAX_JSON:
            raise ValueError('Unpacked profile is too large.')
        for info in infos:
            limit = MAX_JSON if info.filename == 'profile.json' else MAX_IMAGE
            if info.file_size > limit or info.flag_bits & 1:
                raise ValueError('Oversized or encrypted ZIP entry.')
        manifest = json.loads(archive.read('profile.json'))
        if not isinstance(manifest, dict) or type(manifest.get('version')) is not int:
            raise ValueError('Unsupported TLBStacks profile format or version.')
        if manifest.get('format') == 'TLBStacksGroup':
            if not allow_group or manifest['version'] not in (1, 2):
                raise ValueError('This archive requires a compatible TLBStacks Group widget.')
            group = validate_group(manifest.get('group'), allow_references=True)
            settings_list = []
            for item in group['items']:
                if item['type'] == 'stack':
                    unpack_folder(item['settings'], item, request)
                    settings_list.append(item['settings'])
                else:
                    settings_list.append(item)
            result = dict(ok=True, kind='group', group=group)
        elif manifest.get('format') in ('TLBStacks', 'TrueLaunchBar') and manifest['version'] in (1, 2, 3, 4, 5):
            settings = validate_settings(manifest.get('settings'))
            if 'folderLocation' in manifest and manifest['version'] != 5:
                raise ValueError('Conflicting portable folder settings.')
            unpack_folder(settings, manifest, request)
            settings_list = [settings]
            result = dict(ok=True, kind='stack', settings=settings)
        else:
            raise ValueError('Unsupported TLBStacks profile format or version.')
        assets = {}
        # Validate all stacks and assets before writing even one managed image.
        def check(value):
            if value.startswith('assets/'):
                if not ASSET.fullmatch(value) or value not in names:
                    raise ValueError('Missing or invalid icon asset.')
                data = archive.read(value)
                if not data or hashlib.sha256(data).hexdigest() != Path(value).stem:
                    raise ValueError('Icon asset checksum does not match.')
                assets[value] = data
                return value
            return theme_icon(value)
        for settings in settings_list:
            map_icons(settings, check)
    def restore(value):
        if value in assets:
            return store_image(assets[value], Path(value).suffix)
        return value
    for settings in settings_list:
        settings.update(map_icons(settings, restore))
    result['folderMissing'] = any(settings.get('folderUrl') and not local_path(settings['folderUrl']).is_dir()
                                  for settings in settings_list)
    return result


def handle(request):
    action = request.get('action')
    if action == 'manageIcon':
        value = text(request.get('icon'), 'icon', 4096)
        if value.startswith('/') or value.startswith('file:'):
            path = local_path(value)
            return dict(ok=True, icon=store_image(image_data(path), path.suffix))
        return dict(ok=True, icon=theme_icon(value))
    if action == 'exportGroup':
        return export_group(request)
    if action == 'importGroup':
        return import_profile(request, allow_group=True)
    if action == 'export':
        return export_profile(request)
    if action == 'import':
        return import_profile(request)
    raise ValueError('Unknown profile operation.')


if __name__ == '__main__':
    try:
        raw = sys.stdin.buffer.read(MAX_JSON + 1)
        if len(raw) > MAX_JSON:
            raise ValueError('Profile request is too large.')
        result = handle(json.loads(raw))
    except Exception as error:
        result = dict(ok=False, error=str(error))
    print(json.dumps(result, ensure_ascii=False))
