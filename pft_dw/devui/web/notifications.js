let timer;
export function notify(message,options={}){const toast=document.querySelector('#toast');if(!toast)return;clearTimeout(timer);toast.textContent=message;toast.classList.add('show');timer=setTimeout(()=>toast.classList.remove('show'),3200);if(options.record!==false)window.dispatchEvent(new CustomEvent('dataflow-notification',{detail:{message}}))}
