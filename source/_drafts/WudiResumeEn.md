---
title: WudiResume
date: 2020-08-21 16:19:25
tags: [Resume]
categories: Essays
mathjax: false
---
# Education Experience

|    | From | To | School |Education| Major |
|:--:|:--:|:--:|:--:|:--:|:--:|
|1|2008.8|2011.6|Senior High|Jiangsu Gaochun Senior High School</br>江苏省高淳高级中学| |
|2|2011.8|2015.6|Bachelor|Soochow University Wenzheng College</br>苏州大学文正学院|Communication Engineering|
|3|2015.9|2018.6|Master|Soochow University Electrical Information College</br>苏州大学电子信息学院|Information and Communication Engineering</br> Field: Medical Image Processing|

# Working Experience

|    | From | To | Company | Duty |
|:--:|:--:|:--:|:--:|:--:|
|1|2016.3|2018.6|Suzhou Big Vision Medical Technology Co.,Ltd</br>苏州比格威医疗科技有限公司|intern and Manager of Platform Dept.|
|2|2018.6|2019.12| ditto | Manager of Platform Dept. |
|3|2020.1|2020.8.| ditto | Manager of Tech Support Dept.|
|3|2019.11|2020.8| ditto | Management Representative|

# Project Experience
1. Ophthalmic PACS   
**Duration**：2016.3 ~ 2016.9   
**Team Size**：3   
**Project Intro**：Ophthalmic PACS (Picture Archiving and Communication System) collects and archives pictures that are captured from patients by ophthalmic equipments. Via the browser, doctors can view the patients' information and pictures when need.   
比格威眼科PACS系统是一个专门用于眼科影像存储、传输的系统。PACS（Picture Archiving and Communication System）将眼科设备（如OCT、眼底相机）中采集的患者影像传输至服务器并归档。当医生需要调阅时，通过浏览器对影像及相关的患者信息和影像信息进行展示。   
**My Duties**：Project Leader, Backend Developer, Client Developer (Java)  
项目负责人，后端开发工程师，客户端开发工程师   
**Main Tech**：DICOM Protocal, Java Spring, Java Swing 
   
2. MIAS   
**Duration**：2017.1 ~ 2018.12   
**Team Size**：6   
**Project Intro**：MIAS (Medical Image Analysis System) is a artificial intelligent diagnosis system for ophthalmology. Base on *Ophthalmic PACS*, MIAS contains AI diagnosis, and is able to serve different roles ( such as doctors, ophthalmologists) and connect to more than twenty equipments.   
MIAS（Medical Image Analysis System）是一款用于眼科影像的人工智能辅助诊断系统。在比格威眼科PACS系统的基础上，增加了对影像的AI辅助诊断，提供对不同角色（医生、专家等）的不同服务，并且能对接数十种设备。   
**My Duties**：Project Leader, Backend Developer, Client Developer（Java+QT）   
**Main Tech**：Java Spring，JNI（C++），Socket，WebSocket，Quartz，Qt

3. Eyestime Eye Health Management System (眼查查眼健康管理系统)   
**Duration**：2018.6 ~ 2018.12   
**Team Size**：9   
**Project Intro**：Eyestime is a client-oriented system. In Eyestime, the user can view her/his own ophthalmic images via the mobile phone application and the WeChat Miniprogram. Benifit from MIAS, Eyestime can presenting data of over 20 equipments, AI opnions and expert diagnosis as well.    
利用MIAS这一B端产品收集的数据，经过整理和汇总，使C端用户可通过App与微信小程序浏览自己的眼科影像及专AI和专家给出的诊断意见。   
**My Duties**：Project Leader, Backend Developer, a little bit Frontend Development.   
项目负责人，后端开发工程师，一点点前端开发工作  
**主要技术**：Java Spring，Message Queue，Ionic

4. BFS File Format   
**Duration**：2019.2 ~ 2019.3   
**Team Size**：1   
**项目简介**：BV1000 is a model of OCT (Optical Coherence Tomography, an ophthalmic equipment for capturing 3D images of human retina). For encryption, easy management and incompetent DICOM protocal, BV1000 needs a storage solution to store structured and unstructured data at the same time. With less cost, a BFS file can store all images and marks, patient info, analysis result and diagnosis together. Also, reliable and easy-to-use APIs are offered.     
BV1000是比格威公司的一款眼科光学相干断层扫描仪，本项目所设计的文件系统用于持久化设备采集的影像数据、患者信息、诊断信息、分析数据、标注数据等结构或非结构数据。   
**My Duties**：BFS Project Leader, Designer, Developer   
**Main Tech**：C++   

5. MIAS updating   
**Duration**：2019.4 ~ 2019.5   
**Team Size**：6   
**Project Intro**：Due to the growing numbers of users and data scales, an updating and evolution plan is badly in need. MIAS was reconstructed with SpringBoot to simplify configuration and add extra flexibility. After that, virtualization and microservice technology are used to provide the posibility for more connections and extense storage, and ready for any instructions to move all the service onto the public cloud platform.     
针对可能日益增长的MIAS用户和数据规模，提出MIAS的升级及演化方案。首先利用SpringBoot改造MIAS，以简化配置、增加灵活性。而后利用容器化技术将3台服务器虚拟为个结点，将MIAS逐步微服务化并配置到k8s中，为可能持续增长的服务和存储的扩展提供可能，并根据政策随时准备迁移至各公有云。  
**My Duties**：Project Leader   
**Main Tech**：SpringBoot， Kubernetes， Nexus。

6. BLemon Eye Health Management System (亮柠檬), Phase I   
**Duration**：2019.6 ~ 2019.12   
**Team Size**：6 developers（and about 4 provided ideas and professional knowledge)   
**Project Intro**：Unlike Eyestime that focus on retina, BLemon concentrates on optometry. BLemon helps optical shops (selling eyeglasses), optometry clinics and ophthalmology hospitals to standardize treatment procedure, digitalize all kind of measurements and images. Also, BLemon provides treatment suggestions and return-visit reminding. 
与眼查查专注于眼底不同，亮柠檬侧重于为眼视光领域提供专业的指导。其主要针对视光诊所、眼科专科医院或迫切希望升级为时光诊所的眼镜店，为其规范视光诊疗流程，电子化各种测量数据和影像，并提供治疗方案建议、复诊复查提醒和记录等功能。   
**My Duties**：Project Leader, requirement analysis
**主要技术**：SpringBoot，Message Queue，Drools

7. LemonElf (Desktop Application for BLemon Phase II)
**Duration**：2020.4 ~ 2020.5
**Team Size**：1
**Project Intro**：LemonElf is installed on the exam equipments to transfer the exam data to BLemon server. LemonElf uses Electron to build the desktop application and Vue to form the window view. For confidentiality, LemonElf uses FFI (Foreign Function Interface) to communicate with dynamic library written in C++ and this makes LemonElf can adapt to variant equipments with a few changes (only replacing the dll file). Via those abstract interfaces, LemonElf collects different types of data (such as pictures, binaries, numerical values) and provides differential preview and converting functions with a description file (no need to change the LemonElf source code).     
亮柠檬二期在一期的基础上增加了ERP系统，并添加了AI算法模块。二期的客户端为眼科检查设备上的客户端，用于将设备检查结果收集并传输至服务器。为了提高开发效率，并解决人手问题，采用Electron构建桌面应用程序，使用Vue快速构建窗口界面，低层抽象为多个接口，为了保密性以ffi与C++编写的dll通过接口交互以适应不同种类和型号设备上数据的不同存储和转换方式，并根据不同种类数据（图片、裸数据、数值等）提供预览、转换上传的功能。   
**My Duties**：Application Constructor, Requirement Analyst, Designer, Developer (exclude dll codes).   
**Main Tech**：Electron, Vue, ffi, Node.js   

8. MIAS Registration and Production Licence(医疗器械注册证与生产许可证)    
**Duration**：2018.3 ~ 2018.12   
**Team Size**：10   
**项目简介**：As a medical equipement, MIAS needs some administrative approvals before producing and selling. A Good Manufacturing Practices (GMP) system is built up to guarantee the designing, producing and selling are all under the law frame and at high quality even when costume using. After China FDA examed the R&D and producing place and verifying the GMP system, we got the Registration Certificate For Medical Device (that means the government recognizes MIAS) and Production Enterpriser Licence of Medlical Instrument (that means  the government allows Big Vision to produce MIAS at the place). 
MIAS作为一款医疗器械，其上市和生产均需建立医疗器械研发生产质量管理规范（Good Manufacturing Practices，GMP）的体系。经FDA实地检查研发生产环境、审核体系后，MIAS获得了医疗器械二类注册证（政府认可该医疗器械的存在性）及生产许可证（政府允许在该生产场地生产该医疗器械）。   
**My Duties**：Designing the structure of r&d and production procedure, overall planning all r&d and production documentation, cooperating with the quality control system, leading the testing period. I'm the main person during system verification.       
设计研发、生产体系架构，统筹所有研发和生产文档的编写，配合质量体系的完成，主导产品检测过程，是现场体系核查和资料评审的主要负责人。   

9. BV1000 Registration and Production Licence  
**Duration**：2019.10 ~ 2020.8   
**Team Size**：15   
**Project Intro**：to get the Registration Certificate For Medical Device and Production Enterpriser Licence of Medlical Instrument of BV1000.  
BV1000作为一款医疗器械，其上市和生产均需建立医疗器械研发生产质量管理规范（Good Manufacturing Practices，GMP）的体系。经FDA实地检查研发生产环境、审核体系后，BV1000获得了医疗器械二类注册证（政府认可该医疗器械的存在性）及生产许可证（政府允许在该生产场地生产该医疗器械）。   
**My Duties**：Designing the structure of r&d, quality control, production, selling procedure, overall planning all period and deparment documentation, writing application for registration and production license. I'm the main person during system verification.   
设计研发、质量、生产、管理、销售体系架构，统筹所有研发、质量、生产、管理文档的编写，注册申报资料和生产许可材料的编写，是现场体系核查和资料评审的主要负责人。

# Skills
## Program Languages
* Java 
* C/C++   
* JavaScript/TypeScript   
* Markdown   
* SQL   

## Frames/libs
* Spring
* Qt
* Electron
* Vue

# Self Evaluation   
I have been interested in computer since kindergarten. When I was 8, I started to acquire knowledge like crazy because a computer appeared in my family. I fixed computer for others at the age of 11 (the most solution is reinstall the system though) and started to learn programming and took part in the competition of National Olympiad in Informatics. After all these years, I still feel that swimming in the computer knowledge is the most enjoyable thing for me.   
Later, I failed in the college entrance examination,  passed the postgraduate entrance examination, and unexpectedly won my postgraduate supervisor's recognition. I started the journey back to CS and SE. The four and a half years in my supervisor's company have greatly improved me. I have benefited a lot both from the free space of my coding skills and the management. Even so, my mentor's experiences at Microsoft, especially the attitude 'proactive', have always fascinated me.   
Today I send out this resume with good expect and hope Microsoft can give me an oppotunity to archieve my dream. At the mean time, I want a chance to empower every person and every organization on the planet to achieve more with Microsoft.
   
自幼儿园第一次接触计算机我就对计算机产生了浓厚的兴趣，二年级时家里购买了第一台电脑我开始疯狂汲取知识，四年级开始帮别人修电脑，初二开始学习编程并参加信息学奥赛，我始终觉得徜徉在计算机知识的海洋中是最令我感到快乐的事情。  
后来高考填报志愿失利，又经过考研，意外获得了导师的认可，重新开始了CS和SE的旅程。在导师公司的这四年半年，给了我极大的提高，无论是技术上的自由发展空间，还是在管理上的谆谆指导，都让我受益匪浅。但导师在微软时的种种经历，特别是proactive的那种态度无时无刻不在吸引着我。   
今天，我满怀期待的投出这份简历，希望微软能够给予我一次机会，以成就自己；同时，也让我有机会与微软一起，予力全球每一人、每一组织，成就不凡。