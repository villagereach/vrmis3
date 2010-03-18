/*This Script allows people to enter by using a form that asks for a
UserID and Password*/
function pasuser(form) {
if (form.id.value=="user") { 
if (form.pass.value=="demo") {              
location="/homepages" 
} else {
alert("Invalid Password")
}
} else {  alert("Invalid UserID")
}
}
