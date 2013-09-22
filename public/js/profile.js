$(document).ready(function(){
    if (!window.location.origin){
     window.location.origin = window.location.protocol+"//"+window.location.host;
    }

    $('body').scrollTop(100)

    var lineage = data.lineage
    var width = 900, height = 900, dgrow = 0.3;

    var cluster = d3.layout.tree()
    .size([width - 200, height - 200]);

    var diagonal = d3.svg.diagonal()
    .projection(function(d) { return [d.x, d.y]; });//flip it onto its side!

    //set up the visualisation:
    var vis = d3.select("#dendrogram").append("svg")
    .attr("width", height)
    .attr("height", width)
    .append("g")
    .attr("transform", "translate(0, 20)"); //once the graph is materialised, transform it 50 to the right (x), 0 up (y)

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
    .attr("transform", function(d) { return "translate(" + d.x + "," + d.y + ")"; })

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
    .attr("dx", function(d) { return d.children ? 10 : 10; })
    .attr("dy", function(d) { return d.children ? 7 : 17; })
    .attr("transform", function(d) { return d.children ? "rotate(0)": "rotate(45)";})
    .attr("text-anchor", function(d) { return d.children ? "start" : "start"; })
    .text(function(d) {
        var marker = d._specimen_type == "slide" ? " : "+d.marker_name : ''
        return d._specimen_type == undefined ? d.level+": "+d.label : d._specimen_type+" : "+d.label+marker;
    });

})
