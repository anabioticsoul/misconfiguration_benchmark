package org.misconfigbench.ca21;

import org.springframework.context.support.FileSystemXmlApplicationContext;

public final class Main {
    public static void main(String[] args) {
        try (FileSystemXmlApplicationContext context = new FileSystemXmlApplicationContext("src/main/resources/applicationContext.xml")) {
            context.getBean("entityManagerFactory");
            System.out.println("SPRING_CONTEXT_STARTED");
        }
    }
}
