let education = document.getElementById('education');
let infrotainment = document.getElementById('infrotainment');
let entertainment = document.getElementById('entertainment');
let tabSelect = document.getElementById('tabSelect').getElementsByTagName("ul")[0].getElementsByTagName("li");

function tabsSwitch(tabName) {
    if (tabName == 'education'){
        education.style.display = 'block';
        infrotainment.style.display = 'none';
        entertainment.style.display = 'none';
        tabSelect[0].classList.remove("gradient-button");
        tabSelect[1].classList.remove("gradient-button");
        tabSelect[2].classList.add("gradient-button");

    }else if(tabName == 'infrotainment'){
        education.style.display = 'none';
        infrotainment.style.display = 'block';
        entertainment.style.display = 'none';
        tabSelect[0].classList.remove("gradient-button");
        tabSelect[1].classList.add("gradient-button");
        tabSelect[2].classList.remove("gradient-button");
    }else{
        education.style.display = 'none';
        infrotainment.style.display = 'none';
        entertainment.style.display = 'block';
        tabSelect[0].classList.add("gradient-button");
        tabSelect[1].classList.remove("gradient-button");
        tabSelect[2].classList.remove("gradient-button");
    }
}