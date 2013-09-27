$(document).ready(function(){
    $('#searchbox').focus().select();

    $('#visualize_nav').attr('class', 'active')

    $('#search_submit').click(function(e){
        e.preventDefault();
        var query = $('#searchbox').val()
        window.location.replace('http://'+window.location.host+'/visualize?'+query+'.json')
        $('#searchbox').focus().select();
        return false;
    });
    //Workaround for non-webkit browsers
    if (!window.location.origin){
     window.location.origin = window.location.protocol+"//"+window.location.host;
    }

    $('body').scrollTop(100)

    var num_children = data.num_children
    var lineage = data.lineage

    var width = 1200, height = (45*num_children)+500, dgrow = 0.3;

    var cluster = d3.layout.tree()
    .size([height - 200, width - 400]);

    var diagonal = d3.svg.diagonal()
    .projection(function(d) { return [d.y, d.x]; });//flip it onto its side!

    //set up the visualisation:
    var vis = d3.select("#dendrogram").append("svg")
    .attr("width", width)
    .attr("height", height)
    .append("g")
    .attr("transform", "translate(90, 0)"); //once the graph is materialised, transform it 50 to the right (x), 0 up (y)

    var nodes = cluster.nodes(lineage);

    var link = vis.selectAll("path.link")
    .data(cluster.links(nodes))
    .enter().append("path")
    .attr("class", "link")
    .attr("d", diagonal);

    var node = vis.selectAll("g.node")
    .data(nodes)
    .enter().append("g")
    .attr("class", "node")
    .attr("transform", function(d) { return "translate(" + d.y + "," + d.x + ")"; })

    //the circles on the nodes:
    node.append("circle")
    .attr("r", 6.5)
    .on("mouseover", function(){
        circle = d3.select(this);
        circle.attr("r", circle.attr("r") * (1+dgrow));
    })
    .on("mouseout", function(){
        circle = d3.select(this);
        circle.attr("r", circle.attr("r") * (1-dgrow));
    })
    .on("click", function(d) {
        var link = (d.id == undefined ? '' : window.location.origin+"/browse/"+d.type+"/"+d.id)
        window.location.href = link
    });

    //where to put the text, if it has children, then place -8 to the left of the node, otherwise, +8 to the right
    node.append("text")
    .attr("dx", function(d) { return d.children ? -10 : 10; })
    .attr("dy", function(d) { return d.children ? 7 : 7; })
    .attr("transform", function(d) { return d.children ? "rotate(-30)": "rotate(0)";})
    .attr("text-anchor", function(d) { return d.children ? "end" : "start"; })
    .text(function(d) {
        var marker = d._specimen_type == "Slide" ? "( "+d.marker_name+" )" : ''
        return d._specimen_type == undefined ? d.level+": "+d.label : d.label+" : "+d._specimen_type+marker;
    });

})
