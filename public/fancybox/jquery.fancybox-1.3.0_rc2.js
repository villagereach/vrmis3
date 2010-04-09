/*

	FancyBox playground - just playing
	v.1.3.0 - RC2 02.01.10

*/
;(function($) {

	var tmp, loading, overlay, wrap, outer, inner, content, close, nav_left, nav_right;

	var selectedIndex = 0, selectedOpts = {}, selectedArray = [], currentIndex = 0, currentOpts = {}, currentArray = [];

	var ajaxLoader = null, imagePreloader = new Image, imageRegExp = /\.(jpg|gif|png|bmp|jpeg)(.*)?$/i, swfRegExp = /[^\.]\.(swf)\s*$/i;

	var loadingTimer, loadingFrame = 1;

	var start_pos, final_pos, busy = false, shadow = 20, fx = $.extend($('<div/>')[0], { prop: 0 }), titleh = 0, isIE6 = !$.support.opacity && !window.XMLHttpRequest;
	
	$.fn.fixPNG = function() {
		return this.each(function () {
			var image = $(this).css('backgroundImage');

			if (image.match(/^url\(["']?(.*\.png)["']?\)$/i)) {
				image = RegExp.$1;
				$(this).css({
					'backgroundImage': 'none',
					'filter': "progid:DXImageTransform.Microsoft.AlphaImageLoader(enabled=true, sizingMethod=" + ($(this).css('backgroundRepeat') == 'no-repeat' ? 'crop' : 'scale') + ", src='" + image + "')"
				}).each(function () {
					var position = $(this).css('position');
					if (position != 'absolute' && position != 'relative')
						$(this).css('position', 'relative');
				});
			}
		});
	};
	
	$.fn.fancybox = function(options) {
		$(this).data('fancybox', $.extend({}, options));

		$(this).unbind('click.fb').bind('click.fb', function(e) {
			e.preventDefault();
			
			if (busy) return;
			
			$(this).blur();

			busy = true;

			selectedArray	= [];
			selectedIndex	= 0;

			var rel = $(this).attr('rel') || '';

			if (!rel || rel == '' || rel === 'nofollow') {
				selectedArray.push(this);

			} else {
				selectedArray	= $("a[rel=" + rel + "], area[rel=" + rel + "]");
				selectedIndex	= selectedArray.index( this );
			}

			fancybox_start();

			return false;
		});

		return this;
	};

	/*

	Public functions

	*/

	$.fancybox = function(obj, opts) {
		if (busy) return;
		
		busy = true;

		selectedArray	= [];
		selectedIndex	= 0;

		if ($.isArray(obj)) {
			for (var i = 0, j = obj.length; i < j; i++) {
				if (typeof obj[i] == 'object') {
					$(obj[i]).data('fancybox', $.extend({}, opts, obj[i]));
				} else {
					obj[i] = $({}).data('fancybox', $.extend({content : obj[i]}, opts));
				}
			}

			selectedArray = jQuery.merge(selectedArray, obj);

		} else {
			if (typeof obj == 'object') {
				$(obj).data('fancybox', $.extend({}, opts, obj));
			} else {
				obj = $({}).data('fancybox', $.extend({content : obj}, opts));
			}

			selectedArray.push(obj);	
		}

		fancybox_start();
	};

	$.fancybox.showActivity = function() {
		clearInterval(loadingTimer);

		loading.show();
		loadingTimer = setInterval(fancybox_animate_loading, 66);
	};

	$.fancybox.prev = function() {
		return $.fancybox.pos( currentIndex - 1);
	};

	$.fancybox.next = function() {
		return $.fancybox.pos( currentIndex + 1);
	};

	$.fancybox.pos = function(pos) {
		if (busy) return;

		pos = parseInt(pos);

		if (pos > -1 && currentArray.length > pos) {
			selectedIndex = pos;
			fancybox_start();
		}

		if (currentOpts.cyclic && currentArray.length > 1 && pos < 0) {
			selectedIndex = currentArray.length - 1;
			fancybox_start();
		}

		if (currentOpts.cyclic && currentArray.length > 1 && pos >= currentArray.length) {
		    selectedIndex = 0;
			fancybox_start();
		}

		return;
	};

	$.fancybox.cancel = function() {
 		if (busy) return;

		busy = true;

		$.event.trigger('fancybox-cancel');

		fancybox_abort();

		if (selectedOpts && $.isFunction(selectedOpts.onCancel)) {
			selectedOpts.onCancel(selectedArray, selectedIndex, selectedOpts);
		};

		busy = false;
	};
	
	// Note:  within an iframe use - parent.$.fancybox.close();
	$.fancybox.close = function() {
		if (busy || wrap.is(':hidden')) {
			return;
		}

		busy = true;

		if (currentOpts && $.isFunction(currentOpts.onCleanup)) {
			if (currentOpts.onCleanup(currentArray, currentIndex, currentOpts) === false) {
				busy = false;
				return;
			}
		};

		fancybox_abort();

		$( close.add( nav_left ).add( nav_right ) ).hide();

		$('#fancybox-title').remove();

		wrap.add(inner).add(overlay).unbind();

		$(window).unbind("resize.fb scroll.fb");
		$(document).unbind('keydown.fb');

		function _cleanup() {
			overlay.fadeOut('fast');

			wrap.hide();
	
			$.event.trigger('fancybox-cleanup');

			inner.empty();

			inner.removeAttr('filter');
			wrap.removeAttr('filter').css('opacity', '');

			if ($.isFunction(currentOpts.onClosed)) {
				currentOpts.onClosed(currentArray, currentIndex, currentOpts);
			}

			currentArray	= selectedOpts	= [];
			currentIndex	= selecteIndex	= 0;
			currentOpts		= selectedOpts	= {};

			busy = false;
		}

		inner.css('overflow', 'hidden');

		if (currentOpts.transitionOut == 'elastic') {
			start_pos = fancybox_get_zoom_from();

			var pos = wrap.position();

 			final_pos = {
				top		:	pos.top ,
				left	:	pos.left,
				width	:	wrap.width(),
				height	:	wrap.height()
			};

			if (currentOpts.opacity) {
				final_pos.opacity = 1;
			}

			fx.prop = 1;

			$(fx).animate({ prop: 0 }, {
				 duration	: currentOpts.speedOut,
				 easing		: currentOpts.easingOut,
				 step		: fancybox_draw,
				 complete	: _cleanup
			});

		} else {
			wrap.fadeOut( currentOpts.transitionOut == 'none' ? 0 : currentOpts.speedOut, _cleanup);
		}
	};

	$.fancybox.resize = function() {
 		if (busy || wrap.is(':hidden')) return;

 		busy = true;

		var c = inner.wrapInner("<div style='overflow:auto'></div>").children();
		var h = c.height();

		wrap.css({height:	h + (currentOpts.padding * 2) + titleh});
		inner.css({height:	h});

		c.replaceWith(c.children());

 		$.fancybox.center();
 	};

	$.fancybox.center = function() {
		busy = true;

		var view	= fancybox_get_viewport();
		var margin	= currentOpts.margin;

		var to = {
			width : wrap.width(),
			height: wrap.height()
		}

		to.top	= view[3] + ((view[1] - (to.height	+ (shadow * 2 ))) * 0.5);
		to.left	= view[2] + ((view[0] - (to.width	+ (shadow * 2 ))) * 0.5);

		to.top	= to.top	< view[3] + margin ? view[3] + margin  : to.top;
		to.left	= to.left	< view[2] + margin ? view[2] + margin  : to.left;

 		$(wrap).css(to);

		busy = false;
	};

	/*

	Inner functions

	*/

	function fancybox_abort() {
		loading.hide();

		$(imagePreloader).unbind();

		if (ajaxLoader) ajaxLoader.abort();

		tmp.empty();
	};

	function fancybox_start() {
		fancybox_abort();

		var obj	= selectedArray[ selectedIndex ];

		if (typeof $(obj).data('fancybox') == 'undefined') {
			selectedOpts = $.extend({}, $.fn.fancybox.defaults, selectedOpts);
		} else {
			selectedOpts = $.extend({}, $.fn.fancybox.defaults, $(obj).data('fancybox'));
		}

		var href, type, title = obj.title || $(obj).title || selectedOpts.title || '';

		if (obj.nodeName && (/^(?:javascript|#)/i).test(obj.href)) {
		    href = selectedOpts.href || null;
		} else {
		    href = obj.href || $(obj).href || selectedOpts.href || null;
		}

		if (selectedOpts.type) {
			type = selectedOpts.type;

			if (!href) href = selectedOpts.content;

		} else if (href) {
			if (href.match(imageRegExp)) {
				type = 'image';

			} else if (href.match(swfRegExp)) {
				type = 'swf';

			} else if ($(obj).hasClass("iframe")) {
				type = 'iframe';

			} else if (href.match(/#/)) {
				obj = href.substr(href.indexOf("#"));

				type = $(obj).length > 0 ? 'inline' : 'ajax';
			} else {
			    type = 'ajax';
			}
		} else {
			if (selectedOpts.content) {
				obj		= selectedOpts.content
				type	= 'html';

				selectedOpts.content = null;
			} else {
				type = 'inline';
			}
		}

		selectedOpts.type	= type;
		selectedOpts.href	= href;
		selectedOpts.title	= title;

		if (selectedOpts.autoDimensions && selectedOpts.type !== 'iframe' && selectedOpts.type !== 'swf') {
			selectedOpts.frameWidth			= 'auto';
			selectedOpts.frameHeight		= 'auto';
		}

		if (selectedOpts.modal) {
		    selectedOpts.overlayShow		= true;
			selectedOpts.hideOnOverlayClick	= false;
			selectedOpts.hideOnContentClick	= false;
			selectedOpts.enableEscapeButton	= false;
			selectedOpts.showCloseButton	= false;
		}

		if ($.isFunction(selectedOpts.onStart)) {
			if (selectedOpts.onStart(selectedArray, selectedIndex, selectedOpts) === false) {
				busy = false;
				return;
			}
		};

		tmp.css('padding', (shadow  + selectedOpts.padding + selectedOpts.margin));

		$('.fancybox-inline-tmp').unbind('fancybox-cancel').bind('fancybox-change', function() {
			$(this).replaceWith(inner.children());
		});

		switch (type) {
			case 'html' :
				tmp.html( obj );

				fancybox_process_inline();
			break;
			
			case 'inline' :
				$('<div class="fancybox-inline-tmp" />').hide().insertBefore( $(obj) ).bind('fancybox-cleanup', function() {
					$(this).replaceWith(inner.children());
				}).bind('fancybox-cancel', function() {
					$(this).replaceWith(tmp.children());
				});

				$(obj).appendTo(tmp);
				
				fancybox_process_inline();
			break;
			
			case 'image':
				imagePreloader = new Image; imagePreloader.src = href;

				if (imagePreloader.complete) {
					fancybox_process_image();

				} else {
					busy = false;
					$.fancybox.showActivity();
					
					$(imagePreloader).unbind().one('load', fancybox_process_image);
				}
			break;
			
			case 'swf':
				var str = '';
				var emb = '';

				str += '<object classid="clsid:D27CDB6E-AE6D-11cf-96B8-444553540000" width="' + selectedOpts.frameWidth + '" height="' + selectedOpts.frameHeight + '"><param name="movie" value="' + href + '"></param>';

				$.each(selectedOpts.swf, function(name, val) {
					str += '<param name="' + name + '" value="' + val + '"></param>';
					emb += ' ' + name + '="' + val + '"';
				});
				
				str += '<embed src="' + href + '" type="application/x-shockwave-flash" width="' + selectedOpts.frameWidth + '" height="' + selectedOpts.frameHeight + '"' + emb + '></embed></object>';
			
 				tmp.html( str );

				fancybox_process_inline();

			break;
	
			case 'ajax':
				var selector	= href.split('#', 2);
				var data		= selectedOpts.ajax.data || {};

				if (selector.length > 1) {
					href = selector[0];

					typeof data == "string" ? data += '&selector=' + selector[1] : data['selector'] = selector[1];
				}

				busy = false;
				$.fancybox.showActivity();
				
				ajaxLoader = $.ajax($.extend(selectedOpts.ajax, {
					url		: href,
					data	: data,
					success	: function(data) {
						tmp.html( data );
			    		fancybox_process_inline();
					}
				}));
			
			break;
			
			case 'iframe' :
				busy = false;
				$.fancybox.showActivity();

				$('<iframe id="fancybox-frame" name="fancybox-frame' + Math.round(Math.random() * 1000) + '" frameborder="0" hspace="0" src="' + href + '"></iframe>').appendTo(tmp).load(function() {
					busy = true;
					
					$(this).unbind();
					
					fancybox_show();
				});

			break;
		}
	};

	function fancybox_process_image() {
		busy = true;

		selectedOpts.frameWidth	 = imagePreloader.width;
		selectedOpts.frameHeight = imagePreloader.height;

		$("<img />").attr({
			'id'	: 'fancybox-img',
			'src'	: imagePreloader.src,
			'alt'	: selectedOpts.title
		}).appendTo( tmp );

		fancybox_show();
	};
	
	function fancybox_process_inline() {
		tmp.width(	selectedOpts.frameWidth );
		tmp.height(	selectedOpts.frameHeight );

		if (selectedOpts.frameWidth		== 'auto') selectedOpts.frameWidth	= tmp.width();
		if (selectedOpts.frameHeight	== 'auto') selectedOpts.frameHeight	= tmp.height();

 		fancybox_show();
	};

	function fancybox_show() {
		loading.hide();

		if (wrap.is(":visible") && $.isFunction(currentOpts.onCleanup)) {
			if (currentOpts.onCleanup(currentArray, currentIndex, currentOpts) === false) {
				$.event.trigger('fancybox-cancel');

				busy = false;
				
				return;
			}
		};

		currentArray	= selectedArray;
 		currentIndex	= selectedIndex;
 		currentOpts		= selectedOpts;

 		inner[0].scrollTop	= 0;
		inner[0].scrollLeft	= 0;

		if (currentOpts.overlayShow) {
		    if (isIE6) {
				$('select:not(#fancybox-tmp select)').filter(function(){
					return this.style.visibility !== 'hidden';
				}).css({'visibility':'hidden'}).one('fancybox-cleanup', function() {
					this.style.visibility = 'inherit';
				});
			}

			overlay.css({
				'background-color'	: currentOpts.overlayColor,
				'opacity'			: currentOpts.overlayOpacity
			}).unbind().show();
		}

		final_pos = fancybox_get_zoom_to();

		fancybox_process_title();

		if (wrap.is(":visible")) {
			$( close.add( nav_left ).add( nav_right ) ).hide();

			var pos = wrap.position();

			start_pos = {
				top		:	pos.top ,
				left	:	pos.left,
				width	:	wrap.width(),
				height	:	wrap.height()
			};

			var equal = (start_pos.width == final_pos.width && start_pos.height == final_pos.height);

			inner.fadeOut(currentOpts.changeFade, function() {
			    $.event.trigger('fancybox-change');

				inner.css({
					top			: currentOpts.padding,
					left		: currentOpts.padding,
					width		: start_pos.width	- (currentOpts.padding * 2) > 0 ? start_pos.width	- (currentOpts.padding * 2) : 1,
					height		: start_pos.height	- (currentOpts.padding * 2) > 0 ? start_pos.height	- (currentOpts.padding * 2) : 1
				}).empty();

				inner.css('overflow', 'hidden');

				function finish_resizing() {
					inner.html( tmp.contents() ).fadeIn(currentOpts.changeFade, _finish);
				}

				fx.prop = 0;

				$(fx).animate({ prop: 1 }, {
					 duration	: equal ? 0 : currentOpts.changeSpeed,
					 easing		: currentOpts.easingChange,
					 step		: fancybox_draw,
					 complete	: finish_resizing
				});
			});

			return;
		}

		if (currentOpts.transitionIn == 'elastic') {
			start_pos = fancybox_get_zoom_from();

			inner.css({
				top			: currentOpts.padding,
				left		: currentOpts.padding,
				width		: start_pos.width	- (currentOpts.padding * 2) > 0 ? start_pos.width	- (currentOpts.padding * 2) : 1,
				height		: start_pos.height	- (currentOpts.padding * 2) > 0 ? start_pos.height	- (currentOpts.padding * 2) : 1
			});

			inner.html( tmp.contents() );

 			wrap.css(start_pos).show();

 			if (currentOpts.opacity) {
				final_pos.opacity = 0;
			}

			fx.prop = 0;

			$(fx).animate({ prop: 1 }, {
				 duration	: currentOpts.speedIn,
				 easing		: currentOpts.easingIn,
				 step		: fancybox_draw,
				 complete	: _finish
			});

		} else {

			inner.css({
				top			: currentOpts.padding,
				left		: currentOpts.padding,
				width		: final_pos.width	- (currentOpts.padding * 2) > 0 ? final_pos.width	- (currentOpts.padding * 2) : 1,
				height		: final_pos.height	- (currentOpts.padding * 2) - titleh > 0 ? final_pos.height	- (currentOpts.padding * 2) - titleh : 1
			});

			inner.html( tmp.contents() );

			wrap.css( final_pos ).fadeIn( currentOpts.transitionIn == 'none' ? 0 : currentOpts.speedIn,  _finish );
		}
	};
	
	function fancybox_draw(pos) {
		var width	= Math.round(start_pos.width	+ (final_pos.width	- start_pos.width)	* pos);
		var height	= Math.round(start_pos.height	+ (final_pos.height	- start_pos.height)	* pos);

		var top		= Math.round(start_pos.top	+ (final_pos.top	- start_pos.top)	* pos);
		var left	= Math.round(start_pos.left	+ (final_pos.left	- start_pos.left)	* pos);

		$(wrap).css({
			'width'		: width		+ 'px',
			'height'	: height	+ 'px',
			'top'		: top		+ 'px',
			'left'		: left		+ 'px'
		});

		width	-= currentOpts.padding * 2;
		height	-= currentOpts.padding * 2 + (titleh * pos);

		width	= width		> 0 ? width		: 0;
		height	= height	> 0 ? height	: 0;

		inner.css({
			'width'		: width		+ 'px',
			'height'	: height	+ 'px'
		});

		if (typeof final_pos.opacity !== 'undefined') {
			var opacity = pos < 0.5 ? 0.5 : pos;

			wrap.css('opacity', opacity);
		}
	};

	function _finish() {
		inner.removeAttr('filter');
		wrap.removeAttr('filter').css('opacity', '');

		if ($(currentArray[ currentIndex ]).is('img') == false && selectedOpts.type !== 'image' && selectedOpts.type !== 'iframe') {
			inner.css({
				'overflow' : 'auto'
			});
		}

  		$('#fancybox-title').show();

		currentOpts.hideOnContentClick ? inner.one('click',		$.fancybox.close )	: inner.unbind();
 		currentOpts.hideOnOverlayClick ? overlay.one('click',	$.fancybox.close )	: overlay.unbind();

 		currentOpts.showCloseButton ? close.show() : close.hide();

		fancybox_set_navigation();

		currentOpts.centerOnScroll ? $(window).bind("resize.fb scroll.fb", $.fancybox.center) : $(window).unbind("resize.fb scroll.fb");
		
		if ($.isFunction(currentOpts.onComplete)) {
			currentOpts.onComplete(currentArray, currentIndex, currentOpts);
		}

		busy = false;

		fancybox_preload_images();
	};

	function fancybox_get_zoom_to() {
		var view	= fancybox_get_viewport();
		var to		= {};

		var margin = currentOpts.margin;
		var resize = currentOpts.autoScale;

		var horizontal_space	= (shadow + margin) * 2 ;
		var vertical_space		= (shadow + margin) * 2 ;
		var double_padding      = (currentOpts.padding * 2);
		
		if (currentOpts.frameWidth.toString().indexOf('%') > -1) {
			to.width = ((view[0] * parseFloat(currentOpts.frameWidth)) / 100) - (shadow * 2) ;

			resize = false;

		} else {
			to.width = currentOpts.frameWidth	+ double_padding;
		}

		if (currentOpts.frameHeight.toString().indexOf('%') > -1) {
			to.height = ((view[1] * parseFloat(currentOpts.frameHeight)) / 100) - (shadow * 2);

			resize = false;
		} else {
			to.height = currentOpts.frameHeight + double_padding;
		}

		if (resize && (to.width > (view[0] - horizontal_space) || to.height > (view[1] - vertical_space))) {
			if ($(currentArray[ currentIndex ]).is('img') || selectedOpts.type == 'image' || selectedOpts.type == 'swf') {
				horizontal_space	+= double_padding;
				vertical_space		+= double_padding;
				
				var ratio = Math.min(Math.min( view[0] - horizontal_space, currentOpts.frameWidth) / currentOpts.frameWidth, Math.min( view[1] - vertical_space, currentOpts.frameHeight) / currentOpts.frameHeight);

				to.width	= Math.round(ratio * (to.width	- double_padding)) + double_padding;
				to.height	= Math.round(ratio * (to.height	- double_padding)) + double_padding;

			} else {
			    to.width    = Math.min(to.width,	(view[0] - horizontal_space));
			    to.height   = Math.min(to.height,	(view[1] - vertical_space));
			}
		}

		to.top	= view[3] + ((view[1] - (to.height	+ (shadow * 2 ))) * 0.5);
		to.left	= view[2] + ((view[0] - (to.width	+ (shadow * 2 ))) * 0.5);

		if (currentOpts.autoScale == false) {
			to.top	= to.top	< view[3] + margin ? view[3] + margin  : to.top;
			to.left	= to.left	< view[2] + margin ? view[2] + margin  : to.left;
		}

		return to;
	};

	function fancybox_get_zoom_from() {
		var obj		= currentArray[ currentIndex ];
		var view	= fancybox_get_viewport();
		var from 	= {
			width	: 1,
			height	: 1,
			top		: view[3] + view[1] * 0.5,
			left	: view[2] + view[0] * 0.5
		};

		var orig_item = false;

 		if (typeof obj.orig !== 'undefined' && obj.orig.nodeName) {
			orig_item = $(obj.orig);

		} else {
			if ($(obj).children("img:first").length) {
				orig_item = $(obj).children("img:first");

			} else if (obj.nodeName) {
				orig_item = $(obj);
			}
		}

		if (orig_item && orig_item.length) {
			var pos = fancybox_get_obj_pos(orig_item);

			from.width	= pos.width		+ (currentOpts.padding * 2);
			from.height	= pos.height	+ (currentOpts.padding * 2);
			from.top	= pos.top		- currentOpts.padding - shadow;
			from.left	= pos.left		- currentOpts.padding - shadow;
		}

		return from;
	};

	function fancybox_set_navigation() {
		$(document).unbind('keydown.fb').bind('keydown.fb', function(e) {
			if (e.keyCode == 27 && currentOpts.enableEscapeButton) {
				e.preventDefault();
				$.fancybox.close();

			} else if(e.keyCode == 37) {
				e.preventDefault();
				$.fancybox.prev();

			} else if(e.keyCode == 39) {
				e.preventDefault();
 				$.fancybox.next();
			}
		});

		if ($.fn.mousewheel) {
			wrap.unbind('mousewheel.fb');

			if (currentArray.length > 1) {
				wrap.bind('mousewheel.fb', function(e, delta) {
					e.preventDefault();

					if (busy || delta == 0) return;

					delta < 0 ? $.fancybox.prev() : $.fancybox.next();
				});
			}
		}

		if (!currentOpts.showNavArrows) return;
		
		if ((currentOpts.cyclic && currentArray.length > 1) || currentIndex != 0) {
			nav_left.show();
		}

		if ((currentOpts.cyclic && currentArray.length > 1) || currentIndex != (currentArray.length -1)) {
			nav_right.show();
		}
	};
	
	function fancybox_preload_images() {
		if ((currentArray.length -1) > currentIndex) {
			var href = currentArray[ currentIndex + 1 ].href;

			if (typeof href !== 'undefined' && href.match(imageRegExp)) {
				var objNext = new Image();
				objNext.src = href;
			}
		}

		if (currentIndex > 0) {
			var href = currentArray[ currentIndex - 1 ].href;

			if (typeof href !== 'undefined' && href.match(imageRegExp)) {
				var objNext = new Image();
				objNext.src = href;
			}
		}
	};
	
	function fancybox_animate_loading() {
		if (!loading.is(':visible')){
			clearInterval(loadingTimer);
			return;
		}

		$('div', loading).css('top', (loadingFrame * -40) + 'px');

		loadingFrame = (loadingFrame + 1) % 12;
	};

	function fancybox_get_viewport() {
		return [ $(window).width(), $(window).height(), $(document).scrollLeft(), $(document).scrollTop() ];
	};

	function fancybox_get_obj_pos(obj) {
		var pos		= obj.offset();

		pos.top		+= parseFloat( obj.css('paddingTop') )	|| 0;
		pos.left	+= parseFloat( obj.css('paddingLeft') )	|| 0;

		pos.top		+= parseFloat( obj.css('border-top-width') )	|| 0;
		pos.left	+= parseFloat( obj.css('border-left-width') )	|| 0;

		pos.width	= obj.width();
		pos.height	= obj.height();

		return pos;
	};
	
	function fancybox_process_title() {
		$('#fancybox-title').remove();

		titleh = 0;

		if (currentOpts.titleShow == false) return false;

		var obj		= currentArray[ currentIndex ];
		var title   = currentOpts.title;

		title = $.isFunction(currentOpts.titleFormat) ? currentOpts.titleFormat(title, currentArray, currentIndex, currentOpts) : fancybox_format_title(title);

		if (title == false || title.length < 1) return;

		if (title.length > 0) {
			var width	= final_pos.width - (currentOpts.padding * 2);
			var titlec	= currentOpts.titlePosition == 'inside' ? 'fancybox-title-inside' : 'fancybox-title-outside';

			$('<div id="fancybox-title" class="' + titlec + '" />').css({
				'width'			: width,
				'paddingLeft'	: currentOpts.padding,
				'paddingRight'	: currentOpts.padding
			}).html(title).appendTo('body');

			titleh = $("#fancybox-title").outerHeight(true);

			if (currentOpts.titlePosition == 'outside') {
				$('#fancybox-title').css('bottom', titleh * -1);
				titleh = 0;
			} else {
			    titleh = titleh - currentOpts.padding;
				final_pos.height += titleh;
			}

			$('#fancybox-title').appendTo( outer ).hide();

			if (isIE6) {
				$('#fancybox-title span').fixPNG();
			}
		}
	};

	function fancybox_format_title(title) {
		if (title.length) {
			return currentOpts.titlePosition == 'inside' ? title : '<span id="fancybox-title-wrap"><span id="fancybox-title-left"></span><span id="fancybox-title-main">' + title + '</span><span id="fancybox-title-right"></span></span>';
		}

		return false;
	};

	function fancybox_init() {
		if ($("#fancybox-wrap").length) return;

		tmp			= $('<div id="fancybox-tmp"></div>').appendTo("body");
		loading		= $('<div id="fancybox-loading"><div></div></div>').appendTo("body");
		overlay		= $('<div id="fancybox-overlay"></div>').appendTo("body");
		wrap		= $('<div id="fancybox-wrap"></div>').appendTo('body');

		outer	= $('<div id="fancybox-outer"></div>')
			.append('<div class="fancy-bg" id="fancy-bg-n"></div><div class="fancy-bg" id="fancy-bg-ne"></div><div class="fancy-bg" id="fancy-bg-e"></div><div class="fancy-bg" id="fancy-bg-se"></div><div class="fancy-bg" id="fancy-bg-s"></div><div class="fancy-bg" id="fancy-bg-sw"></div><div class="fancy-bg" id="fancy-bg-w"></div><div class="fancy-bg" id="fancy-bg-nw"></div>')
			.appendTo( wrap );

		inner	= $('<div id="fancybox-inner"></div').appendTo( outer );
		close	= $('<a id="fancybox-close"></a>').appendTo( outer );

		nav_left	= $('<a href="javascript:;" id="fancybox-left"><span class="fancy-ico" id="fancybox-left-ico"></span></a>').appendTo( outer );
		nav_right	= $('<a href="javascript:;" id="fancybox-right"><span class="fancy-ico" id="fancybox-right-ico"></span></a>').appendTo( outer );

		close.click($.fancybox.close);
		loading.click($.fancybox.cancel);

		nav_left.bind("click", function(e) {
			e.preventDefault();
			$.fancybox.prev();
		});

		nav_right.bind("click", function(e) {
			e.preventDefault();
			$.fancybox.next();
		});

		if (!$.support.opacity) {
			outer.find('.fancy-bg').fixPNG();
		}

		if (isIE6) {
			$(close.add('.fancy-ico').add('div', loading)).fixPNG();

			overlay.get(0).style.setExpression('height',	"document.body.scrollHeight > document.body.offsetHeight ? document.body.scrollHeight : document.body.offsetHeight + 'px'");
			loading.get(0).style.setExpression('top',		"(-20 + ( document.documentElement.clientHeight ? document.documentElement.clientHeight/2 : document.body.clientHeight/2 ) + ( ignoreMe = document.documentElement.scrollTop ? document.documentElement.scrollTop : document.body.scrollTop ) ) + 'px'");

			outer.prepend('<iframe id="fancybox-hide-sel-frame" src="javascript:\'\';" scrolling="no" frameborder="0" ></iframe>');
		}
	};

	$.fn.fancybox.defaults = {
		padding				:	10,
		margin				:	20,
		opacity				:	false,
		modal				:	false,
		cyclic				:	false,

		frameWidth			:	560,
		frameHeight			:	340,

		autoScale			:	true,
		autoDimensions		:	true,
		centerOnScroll		:	false,

		ajax				:	{},
		swf					:	{ wmode: 'transparent' },

		hideOnOverlayClick	:	true,
		hideOnContentClick	:	false,

		overlayShow			:	false,
		overlayOpacity		:	0.3,
		overlayColor		:	'#666',
		
		titleShow			:	true,
		titlePosition		:	'outside', // or 'outside'
		titleFormat			:	null,

		transitionIn		:	'fade', // 'elastic', 'fade', or 'none'
		transitionOut		:	'fade', // 'elastic', 'fade', or 'none'

		speedIn				:	300,
		speedOut			:	300,

		changeSpeed			:	300,
		changeFade			:	'fast',

		easingIn			:	'swing',
		easingOut			:	'swing',

		showCloseButton		:	true,
		showNavArrows		:	true,
 		enableEscapeButton	:	true,
 		
		onStart				:	null,
		onCancel			:	null,
		onComplete			:	null,
		onCleanup			:	null,
		onClosed			:	null
	};

	$(document).ready(function() {
		fancybox_init();
	});
	
})(jQuery);
