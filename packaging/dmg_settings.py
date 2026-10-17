# Styled Sippy installer. Build with:
#   ./.dmgtools/bin/dmgbuild -s packaging/dmg_settings.py Sippy Sippy.dmg
# (run from the project root)
format = 'UDZO'
files = ['dist/Sippy.app']
symlinks = {'Applications': '/Applications'}
background = 'packaging/dmg_bg.png'
volume_icon = 'packaging/AppIcon.icns'
default_view = 'icon-view'
icon_size = 128
window_rect = ((200, 120), (640, 400))
icon_locations = {
    'Sippy.app': (170, 235),
    'Applications': (470, 235),
}
