"""Final source selection and game-texture edge cleanup, with strict QA.

Adobe removed the background and neutralized the green color range. The
packer also removes residual green dominance only on the antialiased outer
boundary (within two output pixels of partial alpha). This preserves alpha,
opaque interior paint, and the independent-illustration provenance. It is
technical cutout cleanup, not generative detail or AI upscaling.
"""
import json
from PIL import ImageFilter
import prepare_lane_refresh as pack

pack.SPECS = {
    'lane.png': ((1024, 400), 'ef800843-52b8-410d-88c7-5e3464e08069', '11e537b4-b345-4e4a-b9ec-eeb0ad15104c'),
    'lane_enemy.png': ((1024, 400), '709faffe-92cb-4c18-97c7-77ec46778643', 'e9306f8e-6d6d-458d-b45e-5f13871140e9'),
    'loading_tip_panel.png': ((900, 160), '0c773de0-1d45-45cc-9fd4-6f440938b413', 'befa0b0d-1230-4d2b-9712-ed57a8d88d56'),
}
original_assemble = pack.assemble
original_get_source = pack.get_source


def source_for_review(url):
    data = original_get_source(url)
    # Keep failed candidates inspectable, but never commit an output unless
    # pack.main passes every check for all three images.
    pack.SOURCES.mkdir(parents=True, exist_ok=True)
    for name, (_size, source_id, _generation_id) in pack.SPECS.items():
        if url.endswith(source_id):
            (pack.SOURCES/name).write_bytes(data)
    return data


def assemble_with_clean_boundary(source, size):
    output, geometry = original_assemble(source, size)
    alpha = output.getchannel('A')
    edge = alpha.filter(ImageFilter.MinFilter(5))
    pixels = output.load()
    edge_pixels = edge.load()
    changed = 0
    for y in range(output.height):
        for x in range(output.width):
            r, g, b, a = pixels[x, y]
            if a and edge_pixels[x, y] < 245 and g > 48 and g > r*1.7 and g > b*1.7:
                pixels[x, y] = (r, max(r, b), b, a)
                changed += 1
    assert output.getchannel('A').tobytes() == alpha.tobytes()
    geometry['boundary_despill'] = {'pixels': changed, 'radius_output_pixels': 2, 'alpha_unchanged': True, 'opaque_interior_untouched': True}
    return output, geometry


pack.get_source = source_for_review
pack.assemble = assemble_with_clean_boundary

if __name__ == '__main__':
    pack.main()
    for path in [pack.SKIN/'manifest.json', pack.SKIN/'manifest_v2.json', pack.SKIN/'manifest_lane_refresh.json', pack.REPORT]:
        report = json.loads(path.read_text(encoding='utf-8'))
        for name in pack.SPECS:
            if name in report['assets']:
                report['assets'][name]['adobe_edge_color_refinement'] = {'target': 'green', 'hue': -80, 'saturation': -70, 'lightness': -35, 'alpha_unchanged': True}
                report['assets'][name]['method'] += '; precision boundary despill after premultiplied resampling'
        pack.json_write(path, report)
