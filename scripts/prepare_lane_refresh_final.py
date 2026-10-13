"""Final source selection; retains every strict pixel/geometry check.

Adobe cutout edges initially retained a green hairline. Adobe's green-only
HSL adjustment (-80 hue, -70 saturation, -35 lightness) neutralized the fringe
without changing the alpha mask or red/bronze paint. The failed first exports
are not delivered. Run this entrypoint to reproduce the final selection.
"""
import json
from pathlib import Path
import prepare_lane_refresh as pack

pack.SPECS = {
    'lane.png': ((1024, 400), 'ef800843-52b8-410d-88c7-5e3464e08069', '11e537b4-b345-4e4a-b9ec-eeb0ad15104c'),
    'lane_enemy.png': ((1024, 400), '709faffe-92cb-4c18-97c7-77ec46778643', 'e9306f8e-6d6d-458d-b45e-5f13871140e9'),
    'loading_tip_panel.png': ((900, 160), '0c773de0-1d45-45cc-9fd4-6f440938b413', 'befa0b0d-1230-4d2b-9712-ed57a8d88d56'),
}

if __name__ == '__main__':
    pack.main()
    for path in [pack.SKIN/'manifest.json', pack.SKIN/'manifest_v2.json', pack.SKIN/'manifest_lane_refresh.json', pack.REPORT]:
        report = json.loads(path.read_text(encoding='utf-8'))
        for name in pack.SPECS:
            if name in report['assets']:
                report['assets'][name]['adobe_edge_color_refinement'] = {'target': 'green', 'hue': -80, 'saturation': -70, 'lightness': -35, 'alpha_unchanged': True}
        pack.json_write(path, report)
