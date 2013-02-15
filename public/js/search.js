$(document).ready(function() {

    $('#searchbox').focus().select();
    $('#search_submit').click(function(e){
        e.preventDefault();
        var query = $('#searchbox').val()
        window.location.replace('http://'+window.location.host+'/search?'+query)
        $('#searchbox').focus().select();
        return false;
    });


    $('#download_results').on('click', function(){
        window.open('/download', '_blank');
        window.focus();
    });

    $('#submit_filters').click(function(e){
        var filters = {}
        $('.filter').each(function(){
            var name = $(this).attr('id')
            filters[name] = $(this).val()
        })
    
    })

    // Add typeahead handler
    options = {
        source: function(query, process){
                    if ( query.length >= 7 ) {
                        return process([])
                    } else {
                        return $.getJSON('/search?'+query+'.json', function(results){
                            console.log(results)
                            return process(_.map(results, function(item){
                                return item["label"] || item["case_number"]
                            }))
                        })
                    }
                },
        minLength: 4
    }
    // $('#searchbox').typeahead(options);
})
