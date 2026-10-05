"""TrueLaunchBar profile transport. JSON stdin/stdout; Python standard library only."""
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
    return Path(root) / 'truelaunchbar/icons'


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
    if source not in ('applications', 'folder', 'categories'):
        raise ValueError('Unknown menu source.')
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
    return dict(menuSource=source, applicationCategories=categories, folderUrl=folder, folderFilters=filters,
                groupName=text(settings.get('groupName', ''), 'menu name', 256),
                groupIcon=text(settings.get('groupIcon', 'applications-all'), 'menu icon', 4096),
                applications=apps, applicationIcons=dict(icons),
                iconsOnly=mode, menuIconSize=size, hoverDelay=delay)


def map_icons(settings, transform):
    result = dict(settings)
    result['groupIcon'] = transform(settings['groupIcon'])
    result['applicationIcons'] = {key: transform(value)
                                  for key, value in settings['applicationIcons'].items()}
    return result


def theme_icon(value):
    if '/' in value or '\\' in value or ':' in value or value in ('.', '..'):
        raise ValueError('Invalid theme icon reference: ' + value)
    return value


def export_profile(request):
    settings = validate_settings(request.get('settings'))
    # Unselected applications' retained overrides need not travel with this menu.
    if settings['menuSource'] != 'categories':
        settings['applicationIcons'] = {key: value for key, value in settings['applicationIcons'].items()
                                        if key in settings['applications']}
    assets = {}
    def pack(value):
        if value.startswith('/') or value.startswith('file:'):
            path = local_path(value)
            data = image_data(path)
            name = 'assets/' + hashlib.sha256(data).hexdigest() + path.suffix.lower()
            assets[name] = data
            if len(assets) > 256 or sum(map(len, assets.values())) > MAX_TOTAL:
                raise ValueError('Too many icon images in this profile (maximum 64 MiB / 256 images).')
            return name
        return theme_icon(value)
    portable = map_icons(settings, pack)
    manifest = json.dumps(dict(format='TrueLaunchBar', version=3, settings=portable),
                          ensure_ascii=False, indent=2).encode('utf-8')
    if len(manifest) > MAX_JSON:
        raise ValueError('Profile settings are too large.')
    destination = local_path(request.get('file'))
    # Refuse accidental replacement of one of the images being exported.
    sources = [settings['groupIcon'], *settings['applicationIcons'].values()]
    if any(destination.resolve() == local_path(icon).resolve()
           for icon in sources if icon.startswith('/') or icon.startswith('file:')):
        raise ValueError('The export file cannot replace a source icon.')
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, 'w', compression=zipfile.ZIP_DEFLATED) as archive:
        archive.writestr('profile.json', manifest)
        for name, data in assets.items():
            archive.writestr(name, data)
    atomic_write(destination, buffer.getvalue())
    return dict(ok=True, file=str(destination))


def import_profile(request):
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
        if not isinstance(manifest, dict) or manifest.get('format') != 'TrueLaunchBar' or type(manifest.get('version')) is not int or manifest['version'] not in (1, 2, 3):
            raise ValueError('Unsupported TrueLaunchBar profile format or version.')
        settings = validate_settings(manifest.get('settings'))
        assets = {}
        # Validate every reference and checksum before storing any images.
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
        map_icons(settings, check)
    def restore(value):
        if value in assets:
            return store_image(assets[value], Path(value).suffix)
        return value
    return dict(ok=True, settings=map_icons(settings, restore))


def handle(request):
    action = request.get('action')
    if action == 'manageIcon':
        value = text(request.get('icon'), 'icon', 4096)
        if value.startswith('/') or value.startswith('file:'):
            path = local_path(value)
            return dict(ok=True, icon=store_image(image_data(path), path.suffix))
        return dict(ok=True, icon=theme_icon(value))
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
