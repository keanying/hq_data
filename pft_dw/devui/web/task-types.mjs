export const TASK_TYPES=[
 {id:'sql',label:'SQL',icon:'SQL',extension:'sql',description:'Spark / Flink / Presto / StarRocks / MySQL'},
 {id:'python',label:'Python',icon:'Py',extension:'py',description:'Python 脚本'},
 {id:'spark_jar',label:'Spark JAR',icon:'SJ',extension:'jar',description:'Spark 程序包',jar:true},
 {id:'flink_jar',label:'Flink JAR',icon:'FJ',extension:'jar',description:'Flink 程序包',jar:true},
 {id:'shell',label:'Shell',icon:'>_',extension:'sh',description:'Shell 脚本'}
];
export const SQL_ENGINES=[{id:'spark',label:'Spark'},{id:'flink',label:'Flink'},{id:'presto',label:'Presto'},{id:'starrocks',label:'StarRocks'},{id:'mysql',label:'MySQL'}];
export const typeOf=t=>TASK_TYPES.find(k=>k.id===t.type)||TASK_TYPES[0];
export const isJar=t=>!!typeOf(t).jar;
export const modeLabel=t=>t.mode==='streaming'?'实时':'离线';
export const taskLabel=t=>t.type==='sql'?`${(SQL_ENGINES.find(e=>e.id===t.engine)||SQL_ENGINES[0]).label} SQL`:typeOf(t).label;
export const defaultMode=(type,engine)=>type==='flink_jar'||(type==='sql'&&engine==='flink')?'streaming':'batch';
export function normalizeTask(t){const type=TASK_TYPES.some(k=>k.id===t.type)?t.type:'sql';const engine=type==='sql'?(SQL_ENGINES.some(e=>e.id===t.engine)?t.engine:'spark'):({spark_jar:'spark',flink_jar:'flink',python:'python',shell:'bash'}[type]);return {...t,type,engine,mode:defaultMode(type,engine)==='batch'?'batch':(['batch','streaming'].includes(t.mode)?t.mode:defaultMode(type,engine)),code:typeof t.code==='string'?t.code:'',jar:{uri:'',mainClass:'',args:'',...(t.jar||{})}};}
export function taskTemplate(t){const name=String(t.name||'新任务').replace(/[\r\n]/g,' ');if(t.type==='python')return `# ${name}\nfrom datetime import date\n\n\ndef main():\n    biz_date = date.today().isoformat()\n    print(f"业务日期: {biz_date}")\n    # 在此编写数据处理逻辑\n\n\nif __name__ == "__main__":\n    main()\n`;
 if(t.type==='shell')return `#!/usr/bin/env bash\n# ${name}\nset -euo pipefail\n\nBIZ_DATE="\${1:-$(date +%F)}"\nprintf '业务日期: %s\\n' "$BIZ_DATE"\n# 在此编写处理命令\n`;
 if(isJar(t))return '';
 if(t.engine==='flink')return `-- ${name}\n-- 先定义 source_table 和 sink_table 的字段及连接器\nSET 'execution.runtime-mode' = '${t.mode==='streaming'?'STREAMING':'BATCH'}';\n\nINSERT INTO sink_table\nSELECT\n    *\nFROM source_table;\n`;
 if(t.engine==='spark')return `-- ${name}\n-- Spark SQL\n\nSELECT\n    *\nFROM source_table\nWHERE dt = '\${bizdate}';\n`;
 return `-- ${name}\n-- ${taskLabel(t)}\n\nSELECT\n    *\nFROM source_table\nLIMIT 100;\n`;
}
export function validateJar(jar){if(!jar.uri?.trim())return '请填写程序包地址';if(!/\.jar(?:[?#].*)?$/i.test(jar.uri.trim()))return '程序包地址应指向 .jar 文件';if(!jar.mainClass?.trim())return '请填写入口类';if(!/^[A-Za-z_$][\w$]*(\.[A-Za-z_$][\w$]*)*$/.test(jar.mainClass.trim()))return '入口类格式不正确，例如 com.example.Main';return null;}
