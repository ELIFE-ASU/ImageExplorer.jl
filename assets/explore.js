async function resizeThat(selector) {
    const width = parseInt(d3.select('input[name="width"]').property('value'));
    const image = d3.select(selector);
    const current_width = parseInt(image.property('width'));
    const current_height = parseInt(image.property('height'));
    const ratio = current_height / current_width;
    image.property('width', width).property('height', width * ratio);
}

async function resizeThis() {
    resizeThat(this);
}

async function setupImage(selector) {
    resizeThat(selector);
    Blink.msg('loaded', d3.select(selector).attr('id'));
}

async function resize() {
    const width = parseInt(d3.select('input[name="width"]').property('value'));
    d3.select('label[for="width"]').html(width + "px");
    d3.selectAll("#plots img").each(resizeThis);
    d3.select('#content').property('min-width', width + "px");
}

async function toggle(ids, visibility) {
    let count = 0;
    d3.zip(ids, visibility).forEach(([id, visible]) => {
        d3.select('#' + id).classed('hidden', !visible);
        count += visible;
    });
    d3.select('#content header h1').html(count + ' Images');
}
