let bar = document.getElementById("bar");
let skillButton = document.getElementById("skill-button");
let timer;

skillButton.addEventListener("click", function() {
    clearInterval(timer);
    let barWidth = parseInt(bar.style.width);
    fetch(`https://${GetParentResourceName()}/skillCheckResult`, {
        method: "POST",
        body: JSON.stringify({ success: barWidth > 10 && barWidth < 90 })
    });
    document.body.style.display = "none";
});

window.addEventListener("message", function(event) {
    if (event.data.action === "openUI") {
        document.body.style.display = "block";
        bar.style.width = "0";
        timer = setInterval(() => {
            let width = parseInt(bar.style.width) || 0;
            bar.style.width = width + 3 + "%";
            if (width >= 100) clearInterval(timer);
        }, 100);
    } else if (event.data.action === "closeUI") {
        document.body.style.display = "none";
        clearInterval(timer);
    }
});
