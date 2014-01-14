var monitors = [];

$(document).ready(function(){

    $('tr.job-working').each(function(index){
        var job_id = $(this).attr('id');
        console.log( job_id );

        var es = new EventSource("/jobs/watch/"+job_id)

        es.addEventListener('open', function(){

        }, false)

        es.addEventListener('message', function(event){
            var data = JSON.parse(event.data)
            var bar = $("#" + job_id + " div.bar");
            bar.width(event.data+"%");
            bar.children().first().text(event.data+"% Complete");

        }, false);

        es.addEventListener('status', function(event){
            console.log(event)
        })

        monitors.push( es )
    });
    /*
    */

});
