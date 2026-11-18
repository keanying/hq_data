import {backend} from './backend.js';
export {backend};
export const defaultProjectId='tourism-default';
export function getProjects(){try{const p=JSON.parse(localStorage.getItem('dataflow-projects-v1'));if(Array.isArray(p)&&p.length)return p}catch{}return [{id:defaultProjectId,name:'文旅数据项目',description:'景区经营、游客洞察与文旅数据开发',owner:'林',createdAt:'2026-10-07'}]}
export const activeProjectId=getProjects().find(p=>p.id===location.hash.split('/')[1])?.id||defaultProjectId;
export const storageKey=(base,id=activeProjectId)=>id===defaultProjectId?base:base+':'+id;
export function emptyProject(name){const root='project-root';return {version:2,folders:[{id:root,name,parentId:null},...['工作流','ODS','DIM','DWD','DWS','ADS'].map((name,i)=>({id:'folder-'+i,name,parentId:root}))],tasks:[],flows:[]}}
