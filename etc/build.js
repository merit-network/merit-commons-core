({
    baseUrl: "../public/js",
    optimize: 'none',
    shim: {
        'jQuery': {
            exports: 'jquery'
        },
        'bootstrap': {
            deps: ['jquery'],
            exports: 'jquery'
        }, 
        'backbone': {
            deps: ['underscore', 'jquery'],
            exports: 'Backbone'
        },
        'underscore': {
            exports: "_"
        },
        'modernizr': {
            exports: "Modernizr"
        },
        'tagsInput': {
            deps: ['jquery']
        },
        'dropzone': {
            exports: "Dropzone"
        },
        'emoji': {
            exports: "emoji"
        },
        'noty': {
            deps: ['jquery'],
            exports: "Noty"
        },
        'scrolltofixed': {
            exports: "Scrolltofixed"
        },
        'htmlsanitizer': {
            exports: "HTMLSanitizer"
        },
        'typeahead': {
            exports: "Typeahead"
        },
        'bootstrapSwitch': {
            exports: 'BootstrapSwitch'
        },
        'spin': {
            exports: 'Spinner'
        },
        'html-md': {
            exports: 'HtmlMD'
        },
        'bootstrap-dialog': {
            deps: ['bootstrap'],
            exports: 'BootstrapDialog'
        },
        'utf8': {
            exports: 'utf8',
        },
        'summernoteRecipientAutocomplete': {
            deps: ['summernote']
        },
        'summernoteImageUpload': {
            deps: ['summernote']
        },
        'summernoteKeyHandler': {
            deps: ['summernote']
        },
        'select2': {
            deps: ['jquery-mousewheel']
        },
        'jquery-mousewheel': {
            deps: ['jquery']
        },
        'odometer': {
            exports: "Odometer"
        },
        'bootstrap-fileinput': {
            exports: "BootstrapFileinput"
        },
        'readmore': {
            deps: ['jquery']
        },
        'moment': {
            exports: 'moment',
        }
    },    
    paths: {
        jquery: 'libs/jquery/jquery',
        underscore: 'libs/underscore/underscore',
        backbone: 'libs/backbone/backbone',
        bootstrap: 'libs/bootstrap/bootstrap',
        bootstrapSwitch: 'libs/bootstrap/bootstrap-switch',
        mustache: 'libs/mustache/mustache',
        modernizr: 'libs/modernizr/modernizr',
        text: 'libs/require/text',        
        tagsInput: 'libs/jquery/jquery.tagsinput',
        dropzone: 'libs/dropzone/dropzone',
        emoji: 'libs/emoji/emoji',
        noty: 'libs/noty/noty',
        htmlsanitizer: 'libs/htmlsanitizer/htmlsanitizer',
        scrolltofixed: 'libs/scrolltofixed/scrolltofixed-min',
        typeahead: 'libs/typeahead/typeahead',
        spin: 'libs/spin/spin-min',
        utf8: 'libs/utf8/utf8',
        bootstrapFileinput: 'libs/bootstrap-fileinput/bootstrap-fileinput',
        'bootstrap-dialog': 'libs/bootstrap-dialog/bootstrap-dialog',
        'html-md': 'libs/html-md/md',
        'summernoteRecipientAutocomplete': 'summernote_plugins/recipient_autocomplete',
        'summernoteImageUpload': 'summernote_plugins/image_upload',
        'summernoteKeyHandler': 'summernote_plugins/key_handler',
        'jquery-mousewheel': 'libs/jquery-mousewheel/jquery-mousewheel',
        'odometer': 'libs/odometer/odometer',
        readmore: 'libs/readmore/readmore',
        moment: 'libs/moment/moment',
        'moment-timezone': 'libs/moment/moment-timezone',
    },
    packages: [
        {
            name: 'summernote',
            location: 'libs/summernote',
            main: 'summernote'
        },
        {
            name: 'select2',
            location: 'libs/select2',
            main: 'jquery.select2'
        },
        {
            name: 'cron-parser',
            location: 'libs/cron-parser',
            main: 'parser'
        }
    ],
    name: "main"
})