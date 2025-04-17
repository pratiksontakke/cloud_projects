
import React from "react";
import { ExternalLink, Globe, Cloud, Phone, Mail, Linkedin, Github } from "lucide-react";

const Footer = () => {
  return (
    <footer className="bg-scientific-dark text-white py-6 mt-auto">
      <div className="container mx-auto px-6">
        <div className="flex flex-col md:flex-row justify-between items-center">
          <div className="mb-4 md:mb-0">
            <p>© 2025 Tutorials Management System</p>
          </div>
          
          <div className="mb-4 md:mb-0 bg-white/10 backdrop-blur-sm rounded-lg px-4 py-3 text-sm">
            <p className="font-semibold mb-2 text-center">Looking for enterprise-grade cloud architecture?</p>
            <div className="grid grid-cols-2 gap-x-4 gap-y-2">
              <div className="flex items-center">
                <Cloud size={16} className="mr-1.5 text-scientific-teal" />
                <span>Scalable Solutions</span>
              </div>
              <div className="flex items-center">
                <Globe size={16} className="mr-1.5 text-scientific-blue" />
                <span>Global Deployment</span>
              </div>
            </div>
          </div>
          
          <div className="flex flex-col items-center md:items-end">
            <a
              href="https://www.pratiksontakke.com/"
              target="_blank"
              rel="noopener noreferrer"
              className="text-scientific-light hover:text-white transition-colors flex items-center gap-2 mb-2"
            >
              <Globe size={14} /> www.pratiksontakke.com <ExternalLink size={14} />
            </a>
            <div className="flex gap-3 mt-1">
              <a 
                href="mailto:info@pratiksontakke.com" 
                className="text-white/80 hover:text-white transition-colors"
                title="Email me"
              >
                <Mail size={16} />
              </a>
              <a 
                href="tel:+1234567890" 
                className="text-white/80 hover:text-white transition-colors"
                title="Call me"
              >
                <Phone size={16} />
              </a>
              <a 
                href="https://linkedin.com/in/pratiksontakke" 
                target="_blank" 
                rel="noopener noreferrer" 
                className="text-white/80 hover:text-white transition-colors"
                title="LinkedIn"
              >
                <Linkedin size={16} />
              </a>
              <a 
                href="https://github.com/pratiksontakke" 
                target="_blank" 
                rel="noopener noreferrer" 
                className="text-white/80 hover:text-white transition-colors"
                title="GitHub"
              >
                <Github size={16} />
              </a>
            </div>
          </div>
        </div>
      </div>
    </footer>
  );
};

export default Footer;
