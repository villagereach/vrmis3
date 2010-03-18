// Place your application-specific JavaScript functions and classes here
// This file is automatically included by javascript_include_tag :defaults

function changePageLanguage(path) {
    window.location.href = path + '?locale=' + $F('locale');
}

function setVisitMonth() {
    // TODO: Ajaxify this
    $('set_visits_month_form').submit();
}

function toggleDiv(id) {
    $(id).toggle();
}