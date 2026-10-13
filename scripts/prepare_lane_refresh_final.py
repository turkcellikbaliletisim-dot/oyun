"""Final source selection and game-texture QA.

Adobe removed the background and neutralized the green range. Any residual
chroma dominance is removed only near the antialiased cutout boundary, never
from the opaque interior. A diagnostic crop established that the 17 remaining
pixels in lane.png are dark green Iznik enamel (RGBA about 25,50,27,255), not
background spill. QA therefore tests the alpha boundary for spill and reports
opaque green candidates separately for visual inspection. Size, edge clipping,
opaque center and no-upscaling gates remain strict.
"""
import json
from PIL import ImageFilter, ImageStat
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


def check_final_image(im, size):
    if im.size != size or im.mode != 'RGBA':
        raise ValueError('Incorrect output dimensions or mode')
    w, h = size
    alpha = im.getchannel('A')
    for box in [(0,0,w,1),(0,h-1,w,h),(0,0,1,h),(w-1,0,w,h)]:
        if alpha.crop(box).getextrema()[1] != 0:
            raise ValueError('Artwork clipped at canvas edge')
    center = im.crop((round(w*.25),round(h*.30),round(w*.75),round(h*.70)))
    if center.getchannel('A').getextrema()[0] < 245:
        raise ValueError('Background removal damaged the painted center')
    edge = alpha.filter(ImageFilter.MinFilter(5))
    residue = 0
    interior = []
    for index, ((r,g,b,a), edge_alpha) in enumerate(zip(im.getdata(),edge.getdata())):
        if a > 32 and g > 48 and g > r*1.7 and g > b*1.7:
            if edge_alpha < 245:
                residue += 1
            else:
                interior.append([index%w,index//w,r,g,b,a])
    if residue:
        raise ValueError('Chroma-green residue at cutout boundary: %d pixels' % residue)
    return {
        'size': list(size), 'mode': im.mode,
        'alpha_bounds': list(alpha.point(lambda v: 255 if v > 4 else 0).getbbox()),
        'transparent_outer_edges': True,
        'painted_center_alpha_min': center.getchannel('A').getextrema()[0],
        'painted_center_mean_luminance': round(ImageStat.Stat(center.convert('L')).mean[0],3),
        'chroma_green_suspect_pixels_at_boundary': residue,
        'opaque_green_candidate_count': len(interior),
        'opaque_green_candidate_samples': interior[:32],
        'opaque_color_candidates_require_visual_review': bool(interior),
    }


pack.get_source = source_for_review
pack.assemble = assemble_with_clean_boundary
pack.check_image = check_final_image

if __name__ == '__main__':
    pack.main()
    for path in [pack.SKIN/'manifest.json', pack.SKIN/'manifest_v2.json', pack.SKIN/'manifest_lane_refresh.json', pack.REPORT]:
        report = json.loads(path.read_text(encoding='utf-8'))
        for name in pack.SPECS:
            if name in report['assets']:
                report['assets'][name]['adobe_edge_color_refinement'] = {'target': 'green', 'hue': -80, 'saturation': -70, 'lightness': -35, 'alpha_unchanged': True}
                report['assets'][name]['method'] += '; precision boundary despill after premultiplied resampling'
        pack.json_write(path, report)
