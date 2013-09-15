$(document).ready(function(){
    $('body').scrollTop(100)

    var width = 1300, height = 1200, dgrow = 0.2;

    var cluster = d3.layout.tree()
    .size([height - 200, width - 200]);

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
        window.location = "http://localhost:5000/browse/specimen/03071239"
    });

    //where to put the text, if it has children, then place -8 to the left of the node, otherwise, +8 to the right
    node.append("text")
    .attr("dx", function(d) { return d.children ? -10 : 10; })
    .attr("dy", function(d) { return d.children ? 5 : -10; })
    .attr("transform", "rotate(45)")
    .attr("text-anchor", function(d) { return d.children ? "end" : "start"; })
    .text(function(d) {
        var sz = (d.size == undefined ? '': ' => '+d.size+' classes');
        return d.name + sz;
    });

})
